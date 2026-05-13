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
         u.is_premium_user,
         latest.msg as last_message,
         latest.time as last_message_time,
         latest.mtype as last_message_type,
         (SELECT COUNT(*)::int FROM messages 
          WHERE channel_id = c.id AND sender_id != $1 AND read_at IS NULL) as unread_count
       FROM channels c
       JOIN users u ON (CASE WHEN c.user1_id = $1 THEN c.user2_id ELSE c.user1_id END) = u.id
       LEFT JOIN profiles p ON p.user_id = u.id
       LEFT JOIN LATERAL (
         SELECT content as msg, created_at as time, message_type as mtype
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
            // Privacy-aware online status
            const isOnline = onlineTracker.canSeeOnlineStatus(peerId, userId);
            const lastSeen = (row.last_seen_enabled !== false) ? row.last_seen_at : null;
            
            // Check if typing TO ME
            const isTyping = onlineTracker.isTypingTo(peerId, userId);

            return {
                channel_id: row.channel_id,
                profile: {
                    id: peerId,
                    display_name: row.display_name,
                    age: row.age,
                    photos: parseJson(row.photos),
                    is_online: isOnline,
                    last_seen: lastSeen,
                    is_premium_user: row.is_premium_user,
                    is_typing: isTyping
                },
                last_message: row.last_message_type === 'voice' 
                    ? 'Voice Message 🎤' 
                    : (row.last_message_type === 'game_status' ? 'Game Activity 🎲' : (row.last_message || null)),
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
        const channelRes = await db.query(`SELECT user1_id, user2_id FROM channels WHERE id = $1`, [channelId]);
        if (channelRes.rows.length > 0) {
            const { user1_id, user2_id } = channelRes.rows[0];
            const peerId = user1_id === userId ? user2_id : user1_id;
            
            // Notify the marker (me) to refresh counts
            io.to(userId).emit('unread_update', { channelId });

            // Check if reader (me) has read receipts enabled before notifying sender (peer)
            const readerRes = await db.query('SELECT read_receipt_enabled FROM profiles WHERE user_id = $1', [userId]);
            if (readerRes.rows.length > 0 && readerRes.rows[0].read_receipt_enabled !== false) {
                // Notify the sender (peer) that their message was read
                io.to(peerId).emit('message_read', { 
                    channelId, 
                    readerId: userId,
                    readAt: new Date().toISOString()
                });
            }
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

        const result = await db.query(
            `SELECT m.id, m.sender_id, m.content, m.message_type, m.duration, m.created_at, m.read_at, m.reply_to_id,
                    rm.content as reply_to_content,
                    rm.sender_id as reply_to_sender_id,
                    rm.message_type as reply_to_message_type,
                    m.snapshot,
                    p_peer.read_receipt_enabled as peer_read_receipt_enabled,
                    COALESCE(
                      (SELECT json_agg(json_build_object('userId', user_id, 'reaction', reaction))
                       FROM message_reactions WHERE message_id = m.id),
                      '[]'
                    ) as reactions
             FROM messages m
             JOIN channels c ON m.channel_id = c.id
             LEFT JOIN messages rm ON m.reply_to_id = rm.id
             JOIN profiles p_peer ON (CASE WHEN m.sender_id = $2 THEN (CASE WHEN c.user1_id = $2 THEN c.user2_id ELSE c.user1_id END) ELSE m.sender_id END) = p_peer.user_id
             WHERE m.channel_id = $1
             ORDER BY m.created_at ASC
             LIMIT 200`,
            [channelId, userId]
        );

        res.json({
            messages: result.rows.map(m => {
                const isSentByMe = m.sender_id === userId;
                const readAt = (isSentByMe && m.peer_read_receipt_enabled === false) ? null : m.read_at;
                
                return {
                    id: m.id,
                    sender_id: m.sender_id,
                    content: m.content,
                    message_type: m.message_type,
                    duration: m.duration,
                    created_at: m.created_at,
                    read_at: readAt,
                    reply_to_id: m.reply_to_id,
                    reply_to_content: m.reply_to_content,
                    reply_to_sender_id: m.reply_to_sender_id,
                    reply_to_message_type: m.reply_to_message_type,
                    snapshot: typeof m.snapshot === 'string' ? JSON.parse(m.snapshot) : (m.snapshot || {}),
                    reactions: typeof m.reactions === 'string' ? JSON.parse(m.reactions) : m.reactions
                };
            })
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
        const { channelId, content, message_type, duration, reply_to_id, clientTempId } = req.body;

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

        // Check if peer is actively viewing this conversation for immediate read receipt
        const io = socketManager.getIo();
        let readAt = null;
        
        // We'll need a way to check active conversations globally. 
        // I'll add a helper to server.js or export the map.
        // For now, I'll check if the peer is online and we'll handle the 'read_at' update.
        // Actually, let's just emit and let the client or server-side socket listener handle it.
        // Better: check the map we created in server.js.
        // I'll export activeConversations from server.js.
        
        const { activeConversations } = require('../state');
        if (activeConversations && activeConversations.get(peerId.toString()) === channelId) {
            readAt = new Date();
        }

        // --- WhatsApp Fix: Capture settings snapshot at send-time ---
        const settingsRes = await db.query(
            `SELECT user_id, read_receipt_enabled, last_seen_enabled, typing_indicator_enabled, e2e_encryption_enabled 
             FROM profiles 
             WHERE user_id IN ($1, $2)`,
            [senderId, peerId]
        );

        const senderProfile = settingsRes.rows.find(r => r.user_id === senderId) || {};
        const peerProfile = settingsRes.rows.find(r => r.user_id === peerId) || {};

        const snapshot = {
            sender: {
                readReceiptsEnabled: senderProfile.read_receipt_enabled !== false,
                lastSeenEnabled: senderProfile.last_seen_enabled !== false,
                typingEnabled: senderProfile.typing_indicator_enabled !== false,
                e2eeEnabled: senderProfile.e2e_encryption_enabled === true
            },
            peer: {
                readReceiptsEnabled: peerProfile.read_receipt_enabled !== false,
                lastSeenEnabled: peerProfile.last_seen_enabled !== false,
                typingEnabled: peerProfile.typing_indicator_enabled !== false,
                e2eeEnabled: peerProfile.e2e_encryption_enabled === true
            }
        };

        const result = await db.query(
            `INSERT INTO messages (channel_id, sender_id, content, message_type, duration, reply_to_id, read_at, snapshot)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
             RETURNING id, created_at, read_at`,
            [channelId, senderId, content.trim(), message_type || 'text', duration || null, reply_to_id || null, readAt, JSON.stringify(snapshot)]
        );

        // Fetch reply context for broadcast if it exists
        let replyContext = null;
        if (reply_to_id) {
            const replyMsg = await db.query(
                'SELECT content, sender_id, message_type FROM messages WHERE id = $1',
                [reply_to_id]
            );
            if (replyMsg.rows.length > 0) {
                replyContext = {
                    content: replyMsg.rows[0].content,
                    sender_id: replyMsg.rows[0].sender_id,
                    message_type: replyMsg.rows[0].message_type
                };
            }
        }

        const message = {
            id: result.rows[0].id,
            sender_id: senderId,
            content: content.trim(),
            message_type: message_type || 'text',
            duration: duration || null,
            created_at: result.rows[0].created_at,
            channel_id: channelId,
            reply_to_id: reply_to_id || null,
            reply_to_content: replyContext?.content,
            reply_to_sender_id: replyContext?.sender_id,
            reply_to_message_type: replyContext?.message_type,
            client_temp_id: clientTempId || null,
            snapshot: snapshot
        };

        // Emit to peer
        io.to(peerId.toString()).emit('new_message', message);
        // Also notify me to update my list preview/sorting
        io.to(senderId.toString()).emit('new_message', message);

        // ── Streak Logic ──
        try {
            // Find or create streak record
            const streakRes = await db.query(
                `SELECT id, count, last_message_at 
                 FROM streaks 
                 WHERE (user1_id = $1 AND user2_id = $2) 
                    OR (user1_id = $2 AND user2_id = $1)`,
                [senderId, peerId]
            );

            let newCount = 1;
            if (streakRes.rows.length > 0) {
                const streak = streakRes.rows[0];
                const lastMsgAt = new Date(streak.last_message_at);
                const now = new Date();
                
                // Check if last message was today (ignore) or yesterday (increment) or older (reset)
                const diffDays = Math.floor((now - lastMsgAt) / (1000 * 60 * 60 * 24));
                
                if (diffDays === 1) {
                    newCount = streak.count + 1;
                } else if (diffDays === 0) {
                    newCount = streak.count; // No change if multiple messages same day
                } else {
                    newCount = 1; // Reset if more than 1 day gap
                }

                await db.query(
                    'UPDATE streaks SET count = $1, last_message_at = NOW() WHERE id = $2',
                    [newCount, streak.id]
                );
            } else {
                await db.query(
                    'INSERT INTO streaks (user1_id, user2_id, count, last_message_at) VALUES ($1, $2, 1, NOW())',
                    [senderId, peerId]
                );
            }

            // Update user's overall streak count and popularity score
            const updateStreakCount = async (uid) => {
                const sumRes = await db.query(
                    'SELECT SUM(count)::int as total FROM streaks WHERE user1_id = $1 OR user2_id = $1',
                    [uid]
                );
                const totalStreaks = sumRes.rows[0].total || 0;
                await db.query('UPDATE profiles SET streak_count = $1 WHERE user_id = $2', [totalStreaks, uid]);
                
                // Trigger popularity update (we can import it or just do it here)
                await db.query(`
                    UPDATE profiles 
                    SET popularity_score = (
                      (likes_count * 2) + 
                      (streak_count * 5) + 
                      (CASE 
                        WHEN last_seen_at >= NOW() - INTERVAL '1 day' THEN 10
                        WHEN last_seen_at >= NOW() - INTERVAL '3 days' THEN 5
                        ELSE 0
                       END)
                    )
                    WHERE user_id = $1
                `, [uid]);
            };

            await updateStreakCount(senderId);
            await updateStreakCount(peerId);

        } catch (err) {
            console.error('Streak update error:', err);
        }

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
            `SELECT u.id, u.is_premium_user, p.display_name, p.photos, b.created_at
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
                is_premium_user: row.is_premium_user,
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