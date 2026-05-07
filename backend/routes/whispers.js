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
            `SELECT id, sender_id, content, message_type, duration, created_at, read_at
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
                message_type: m.message_type,
                duration: m.duration,
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
        const { channelId, content, message_type, duration } = req.body;

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

        const peerId = user1_id === senderId ? user2_id : user1_id;

        // Check if blocked
        const blockCheck = await db.query(
            `SELECT 1 FROM blocks 
             WHERE (blocker_id = $1 AND blocked_id = $2) 
                OR (blocker_id = $2 AND blocked_id = $1)`,
            [senderId, peerId]
        );
        if (blockCheck.rows.length > 0) {
            return res.status(403).json({ error: 'User is blocked' });
        }

        const result = await db.query(
            `INSERT INTO messages (channel_id, sender_id, content, message_type, duration)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, created_at`,
            [channelId, senderId, content.trim(), message_type || 'text', duration || null]
        );

        const message = {
            id: result.rows[0].id,
            sender_id: senderId,
            content: content.trim(),
            message_type: message_type || 'text',
            duration: duration || null,
            created_at: result.rows[0].created_at,
            channel_id: channelId
        };

        // Emit to peer
        const io = socketManager.getIo();
        io.to(peerId).emit('new_message', message);
        // Also notify me to update my list preview/sorting
        io.to(senderId).emit('new_message', message);

        res.json({ message });
    } catch (err) {
        console.error('Send message error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Block a user
router.post('/block', authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { blockedUserId } = req.body;
        if (!blockedUserId) return res.status(400).json({ error: 'blockedUserId required' });

        await db.query(
            `INSERT INTO blocks (blocker_id, blocked_id) VALUES ($1, $2)
       ON CONFLICT DO NOTHING`,
            [userId, blockedUserId]
        );

        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Unblock a user
router.post('/unblock', authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { blockedUserId } = req.body;
        if (!blockedUserId) return res.status(400).json({ error: 'blockedUserId required' });

        await db.query(
            `DELETE FROM blocks WHERE blocker_id = $1 AND blocked_id = $2`,
            [userId, blockedUserId]
        );

        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Report a user
router.post('/report', authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { reportedUserId, reason } = req.body;
        if (!reportedUserId || !reason) return res.status(400).json({ error: 'reportedUserId and reason required' });

        await db.query(
            `INSERT INTO reports (reporter_id, reported_id, reason) VALUES ($1, $2, $3)`,
            [userId, reportedUserId, reason]
        );

        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Get list of blocked users
router.get('/blocked', authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const result = await db.query(
            `SELECT u.id, p.display_name, p.photos, b.created_at
             FROM blocks b
             JOIN users u ON b.blocked_id = u.id
             JOIN profiles p ON p.user_id = u.id
             WHERE b.blocker_id = $1
             ORDER BY b.created_at DESC`,
            [userId]
        );

        const blocked = result.rows.map(row => {
            const parseJson = (val) => {
                if (!val) return [];
                if (typeof val === 'string') {
                    try { return JSON.parse(val); } catch (_) { return []; }
                }
                return val;
            };
            return {
                id: row.id,
                display_name: row.display_name,
                photos: parseJson(row.photos),
                blocked_at: row.created_at
            };
        });

        res.json({ blocked });
    } catch (err) {
        console.error('Fetch blocked users error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;