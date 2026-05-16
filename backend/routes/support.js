const express = require('express');
const db = require('../db');
const authMiddleware = require('../middleware/auth');
const router = express.Router();

// Submit a support query
router.post('/submit', authMiddleware, async (req, res) => {
    const { email, name, query } = req.body;

    if (!email || !name || !query) {
        return res.status(400).json({ error: 'Missing required fields: email, name, and query are required.' });
    }

    try {
        await db.query(
            `INSERT INTO support_queries (user_id, email, name, query)
             VALUES ($1, $2, $3, $4)`,
            [req.userId, email, name, query]
        );

        res.json({ success: true, message: 'Your query submitted successfully. Our team will get back to you via email.' });
    } catch (err) {
        console.error('Submit support query error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;
