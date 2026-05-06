const express = require('express');
const authMiddleware = require('../middleware/auth');
const db = require('../db');

const router = express.Router();

// Send a connection request
router.post('/send', authMiddleware, async (req, res) => {
    const senderId = req.userId;
    const { receiverId } = req.body;

    if (!receiverId) return res.status(400).json({ error: 'receiverId required' });
    if (senderId === receiverId) return res.status(400).json({ error: 'Cannot send request to yourself' });

    try {
        await db.query(
            `INSERT INTO connection_requests (sender_id, receiver_id, status)
       VALUES ($1, $2, 'pending')
       ON CONFLICT (sender_id, receiver_id) 
       DO UPDATE SET status = 'pending', created_at = NOW()
       WHERE connection_requests.status = 'rejected'`,
            [senderId, receiverId]
        );
        res.json({ success: true });
    } catch (err) {
        console.error('Send request error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Get pending requests for the current user (where I am the receiver)
router.get('/pending', authMiddleware, async (req, res) => {
    try {
        const result = await db.query(
            `SELECT
         cr.id as request_id,
         cr.created_at,
         u.id as sender_id,
         p.display_name,
         p.age,
         p.bio,
         p.interests,
         p.photos
       FROM connection_requests cr
       JOIN users u ON u.id = cr.sender_id
       JOIN profiles p ON p.user_id = u.id
       WHERE cr.receiver_id = $1 AND cr.status = 'pending'
       ORDER BY cr.created_at DESC`,
            [req.userId]
        );

        const requests = result.rows.map(row => {
            const parseJson = (val) => {
                if (!val) return [];
                if (typeof val === 'string') {
                    try { return JSON.parse(val); } catch (_) { return []; }
                }
                return val;
            };

            return {
                request_id: row.request_id,
                created_at: row.created_at,
                sender: {
                    id: row.sender_id,
                    display_name: row.display_name,
                    age: row.age,
                    bio: row.bio,
                    interests: parseJson(row.interests),
                    photos: parseJson(row.photos),
                }
            };
        });

        res.json({ requests });
    } catch (err) {
        console.error('Pending requests error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Accept a request
router.put('/:id/accept', authMiddleware, async (req, res) => {
    const client = await db.getClient(); // need to get a client for transaction
    try {
        await client.query('BEGIN');

        const result = await client.query(
            `UPDATE connection_requests SET status = 'accepted'
       WHERE id = $1 AND receiver_id = $2 AND status = 'pending'
       RETURNING sender_id, receiver_id`,
            [req.params.id, req.userId]
        );

        if (result.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ error: 'Request not found' });
        }

        const { sender_id, receiver_id } = result.rows[0];

        // Ensure consistent order of user IDs to prevent duplicate channels (e.g. A-B and B-A)
        const [u1, u2] = [sender_id, receiver_id].sort();

        await client.query(
            `INSERT INTO channels (user1_id, user2_id)
       VALUES ($1, $2)
       ON CONFLICT (user1_id, user2_id) DO NOTHING`,
            [u1, u2]
        );

        await client.query('COMMIT');
        res.json({ success: true });
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Accept request error:', err);
        res.status(500).json({ error: 'Internal server error' });
    } finally {
        client.release();
    }
});

// Reject a request
router.put('/:id/reject', authMiddleware, async (req, res) => {
    try {
        await db.query(
            `UPDATE connection_requests SET status = 'rejected'
       WHERE id = $1 AND receiver_id = $2 AND status = 'pending'`,
            [req.params.id, req.userId]
        );
        res.json({ success: true });
    } catch (err) {
        console.error('Reject request error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Get attended requests (history)
router.get('/history', authMiddleware, async (req, res) => {
    try {
        const result = await db.query(
            `SELECT
         cr.id as request_id,
         cr.created_at,
         cr.status,
         u.id as other_user_id,
         p.display_name,
         p.age,
         p.bio,
         p.interests,
         p.photos
       FROM connection_requests cr
       JOIN users u ON (u.id = cr.sender_id OR u.id = cr.receiver_id) AND u.id != $1
       JOIN profiles p ON p.user_id = u.id
       WHERE (cr.receiver_id = $1 OR cr.sender_id = $1) AND cr.status != 'pending'
       ORDER BY cr.created_at DESC`,
            [req.userId]
        );

        const requests = result.rows.map(row => {
            const parseJson = (val) => {
                if (!val) return [];
                if (typeof val === 'string') {
                    try { return JSON.parse(val); } catch (_) { return []; }
                }
                return val;
            };

            return {
                request_id: row.request_id,
                created_at: row.created_at,
                status: row.status,
                sender: {
                    id: row.other_user_id,
                    display_name: row.display_name,
                    age: row.age,
                    bio: row.bio,
                    interests: parseJson(row.interests),
                    photos: parseJson(row.photos),
                }
            };
        });

        res.json({ requests });
    } catch (err) {
        console.error('History requests error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;