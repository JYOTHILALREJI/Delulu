const express = require('express');
const authMiddleware = require('../middleware/auth');
const db = require('../db');

const router = express.Router();

// Like a user
router.post('/like', authMiddleware, async (req, res) => {
    const { likedUserId } = req.body;
    const likerUserId = req.userId;

    if (!likedUserId) {
        return res.status(400).json({ error: 'likedUserId is required' });
    }

    // Prevent self-like
    if (likerUserId === likedUserId) {
        return res.status(400).json({ error: 'You cannot like yourself' });
    }

    try {
        await db.query(
            `INSERT INTO likes (liker_user_id, liked_user_id)
       VALUES ($1, $2)
       ON CONFLICT (liker_user_id, liked_user_id) DO NOTHING`,
            [likerUserId, likedUserId]
        );
        res.json({ success: true });
    } catch (err) {
        console.error('Like error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Get all profiles that the current user has liked
router.get('/liked', authMiddleware, async (req, res) => {
    try {
        const result = await db.query(
            `SELECT
         u.id as user_id,
         p.display_name,
         p.age,
         p.bio,
         p.interests,
         p.photos,
         l.created_at as liked_at,
         cr.status as request_status,
         cr.id as request_id
       FROM likes l
       JOIN users u ON u.id = l.liked_user_id
       JOIN profiles p ON p.user_id = u.id
       LEFT JOIN connection_requests cr ON (cr.sender_id = l.liker_user_id AND cr.receiver_id = l.liked_user_id)
       WHERE l.liker_user_id = $1
         AND NOT EXISTS (
           SELECT 1 FROM channels ch
           WHERE (ch.user1_id = l.liker_user_id AND ch.user2_id = l.liked_user_id)
              OR (ch.user1_id = l.liked_user_id AND ch.user2_id = l.liker_user_id)
         )
       ORDER BY l.created_at DESC`,
            [req.userId]
        );

        const parseField = (field) => {
            if (!field) return [];
            if (typeof field === 'string') {
                try { return JSON.parse(field); } catch (_) { return []; }
            }
            return field;
        };

        const profiles = result.rows.map(row => ({
            id: row.user_id,
            display_name: row.display_name,
            age: row.age,
            bio: row.bio,
            interests: parseField(row.interests),
            photos: parseField(row.photos),
            liked_at: row.liked_at,
            request_status: row.request_status,
            request_id: row.request_id,
        }));

        res.json({ profiles });
    } catch (err) {
        console.error('Fetch liked error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Remove a like
router.delete('/:likedUserId', authMiddleware, async (req, res) => {
    try {
        await db.query(
            'DELETE FROM likes WHERE liker_user_id = $1 AND liked_user_id = $2',
            [req.userId, req.params.likedUserId]
        );
        res.json({ success: true });
    } catch (err) {
        console.error('Delete like error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Get connected signals (history)
router.get('/history', authMiddleware, async (req, res) => {
    try {
        const result = await db.query(
            `SELECT
         u.id as user_id,
         p.display_name,
         p.age,
         p.bio,
         p.interests,
         p.photos,
         l.created_at as liked_at,
         'connected' as status
       FROM likes l
       JOIN users u ON u.id = l.liked_user_id
       JOIN profiles p ON p.user_id = u.id
       JOIN channels ch ON (ch.user1_id = l.liker_user_id AND ch.user2_id = l.liked_user_id)
                        OR (ch.user1_id = l.liked_user_id AND ch.user2_id = l.liker_user_id)
       WHERE l.liker_user_id = $1
       ORDER BY l.created_at DESC`,
            [req.userId]
        );

        const parseField = (field) => {
            if (!field) return [];
            if (typeof field === 'string') {
                try { return JSON.parse(field); } catch (_) { return []; }
            }
            return field;
        };

        const profiles = result.rows.map(row => ({
            id: row.user_id,
            display_name: row.display_name,
            age: row.age,
            bio: row.bio,
            interests: parseField(row.interests),
            photos: parseField(row.photos),
            liked_at: row.liked_at,
            status: row.status,
        }));

        res.json({ profiles });
    } catch (err) {
        console.error('Fetch liked history error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;