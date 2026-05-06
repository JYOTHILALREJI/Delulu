const express = require('express');
const authMiddleware = require('../middleware/auth');
const db = require('../db');
const socketManager = require('../socket');
const onlineTracker = require('../online_tracker');

const router = express.Router();

// Get list of connections (channels) for the current user,
// with the other user's profile and latest message preview.
router.get('/connections', authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;

        const result = await db.query(
            `SELECT 
         c.id as channel_id,
         CASE 
           WHEN c.user1_id = $1 THEN c.user2_id
           ELSE c.user1_id
         END as peer_id,
         COALESCE(p.display_name, u.display_name) as display_name,
         p.age,
         p.photos,
         p.online_status_enabled,
         p.last_seen_enabled,
         p.last_seen_at,
         latest.msg as last_message,
         latest.time as last_message_time,
         (SELECT COUNT(*)::int FROM messages 
          WHERE channel_id = c.id AND sender_id != $1 AND read_at IS NULL) as unread_count
       FROM channels c
       JOIN users u ON (CASE WHEN c.user1_id = $1 THEN c.user2_id ELSE c.user1_id END) = u.id
       LEFT JOIN profiles p ON p.user_id = u.id
       LEFT JOIN LATERAL (
         SELECT content as msg, created_at as time
         FROM messages m
         WHERE m.channel_id = c.id
         ORDER BY m.created_at DESC
         LIMIT 1
       ) latest ON true
       WHERE (c.user1_id = $1 OR c.user2_id = $1)
       ORDER BY (SELECT COUNT(*) FROM messages m2 WHERE m2.channel_id = c.id AND m2.sender_id != $1 AND m2.read_at IS NULL) DESC, COALESCE(latest.time, c.created_at) DESC`,
            [userId]
        );

        const connections = result.rows.map(row => {
            const parseJson = (val) => {
                if (!val) return [];
                if (typeof val === 'string') {
                    try { return JSON.parse(val); } catch (_) { return []; }
                }
                return val;
            };

            const peerId = row.peer_id;
            const isOnline = onlineTracker.isOnline(peerId) && (row.online_status_enabled !== false);
            const lastSeen = (row.last_seen_enabled !== false) ? row.last_seen_at : null;

            return {
                channel_id: row.channel_id,
                profile: {
                    id: peerId,
                    display_name: row.display_name,
                    age: row.age,
                    photos: parseJson(row.photos),
                    is_online: isOnline,
                    last_seen: lastSeen
                },
                last_message: row.last_message || null,
                last_message_time: row.last_message_time || null,
                unread_count: row.unread_count || 0
            };
        });

        res.json({ connections });
    } catch (err) {
        console.error('Get connections error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Get total unread count across all channels
router.get('/unread-total', authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const result = await db.query(
            `SELECT COUNT(*)::int FROM messages m
       JOIN channels c ON m.channel_id = c.id
       WHERE (c.user1_id = $1 OR c.user2_id = $1)
         AND m.sender_id != $1
         AND m.read_at IS NULL`,
            [userId]
        );
        const count = result.rows[0].count;
        console.log(`Unread total for ${userId}: ${count}`);
        res.json({ total_unread: count });
    } catch (err) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Mark all messages in a channel as read
router.post('/mark-read/:channelId', authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const channelId = req.params.channelId;
        await db.query(
            `UPDATE messages SET read_at = NOW()
       WHERE channel_id = $1 AND sender_id != $2 AND read_at IS NULL`,
            [channelId, userId]
        );

        // Emit unread update to the user who marked as read (to refresh their nav bar/list)
        // AND emit to the other user so they see the ticks change
        const io = socketManager.getIo();
        const channel = await db.query(`SELECT user1_id, user2_id FROM channels WHERE id = $1`, [channelId]);
        if (channel.rows.length > 0) {
            const { user1_id, user2_id } = channel.rows[0];
            const peerId = user1_id === userId ? user2_id : user1_id;
            
            // Notify the marker (me) to refresh counts
            io.to(userId).emit('unread_update', { channelId });
            // Notify the sender (peer) that their message was read
            io.to(peerId).emit('message_read', { channelId, readerId: userId });
        }

        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Get messages for a specific channel (paginated? for now all)
router.get('/messages/:channelId', authMiddleware, async (req, res) => {
    try {
        const channelId = req.params.channelId;
        const userId = req.userId;

        // Verify the user is part of this channel
        const channel = await db.query(
            `SELECT user1_id, user2_id FROM channels WHERE id = $1`,
            [channelId]
        );
        if (channel.rows.length === 0) {
            return res.status(404).json({ error: 'Channel not found' });
        }
        const { user1_id, user2_id } = channel.rows[0];
        if (user1_id !== userId && user2_id !== userId) {
            return res.status(403).json({ error: 'Access denied' });
        }

        const messages = await db.query(
            `SELECT id, sender_id, content, created_at, read_at
       FROM messages
       WHERE channel_id = $1
       ORDER BY created_at ASC
       LIMIT 200`,
            [channelId]
        );

        res.json({
            messages: messages.rows.map(m => ({
                id: m.id,
                sender_id: m.sender_id,
                content: m.content,
                created_at: m.created_at,
                read_at: m.read_at,
            }))
        });
    } catch (err) {
        console.error('Get messages error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Send a message
router.post('/send', authMiddleware, async (req, res) => {
    try {
        const senderId = req.userId;
        const { channelId, content } = req.body;

        if (!channelId || !content || content.trim().length === 0) {
            return res.status(400).json({ error: 'channelId and content required' });
        }

        // Verify sender belongs to channel
        const channel = await db.query(
            `SELECT user1_id, user2_id FROM channels WHERE id = $1`,
            [channelId]
        );
        if (channel.rows.length === 0) {
            return res.status(404).json({ error: 'Channel not found' });
        }
        const { user1_id, user2_id } = channel.rows[0];
        if (user1_id !== senderId && user2_id !== senderId) {
            return res.status(403).json({ error: 'Access denied' });
        }

        const result = await db.query(
            `INSERT INTO messages (channel_id, sender_id, content)
       VALUES ($1, $2, $3)
       RETURNING id, created_at`,
            [channelId, senderId, content.trim()]
        );

        const message = {
            id: result.rows[0].id,
            sender_id: senderId,
            content: content.trim(),
            created_at: result.rows[0].created_at,
            channel_id: channelId
        };

        // Emit to peer
        const io = socketManager.getIo();
        const peerId = user1_id === senderId ? user2_id : user1_id;
        io.to(peerId).emit('new_message', message);
        // Also notify me to update my list preview/sorting
        io.to(senderId).emit('new_message', message);

        res.json({ message });
    } catch (err) {
        console.error('Send message error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;