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
         l.created_at as liked_at
       FROM likes l
       JOIN users u ON u.id = l.liked_user_id
       JOIN profiles p ON p.user_id = u.id
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
        }));

        res.json({ profiles });
    } catch (err) {
        console.error('Fetch liked error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;