const express = require('express');
const db = require('../db');
const router = express.Router();

// Get active subscription plans
router.get('/plans', async (req, res) => {
    try {
        const result = await db.query(
            'SELECT id, name, price_text, period_text, tag, savings_text FROM subscription_plans WHERE active = true ORDER BY sort_order ASC'
        );
        res.json({ plans: result.rows });
    } catch (err) {
        console.error('Fetch plans error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Verify purchase and update user status
router.post('/verify', async (req, res) => {
    const { userId, planId, store, transactionId, purchaseToken } = req.body;

    if (!userId || !planId || !store) {
        return res.status(400).json({ error: 'Missing required fields' });
    }

    const client = await db.pool.connect();
    try {
        await client.query('BEGIN');

        // 1. [CRITICAL] In a real app, you MUST verify the purchaseToken with Google/Apple here.
        // For this implementation, we trust the client-side success (Demo purposes).

        // 2. Calculate expiry date based on plan
        let expiryDate = new Date();
        if (planId === 'monthly') {
            expiryDate.setMonth(expiryDate.getMonth() + 1);
        } else if (planId === '6_months') {
            expiryDate.setMonth(expiryDate.getMonth() + 6);
        } else if (planId === 'yearly') {
            expiryDate.setFullYear(expiryDate.getFullYear() + 1);
        }

        // 3. Update profile to is_premium = true
        await client.query(
            'UPDATE profiles SET is_premium = true, premium_since = COALESCE(premium_since, NOW()) WHERE user_id = $1',
            [userId]
        );

        // 4. Record subscription
        await client.query(
            `INSERT INTO subscriptions (user_id, plan_id, store, transaction_id, purchase_token, expiry_date)
             VALUES ($1, $2, $3, $4, $5, $6)
             ON CONFLICT (user_id, transaction_id) DO UPDATE 
             SET plan_id = EXCLUDED.plan_id, expiry_date = EXCLUDED.expiry_date, updated_at = NOW()`,
            [userId, planId, store, transactionId, purchaseToken, expiryDate]
        );

        await client.query('COMMIT');
        res.json({ success: true, message: 'Subscription activated' });
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Verify purchase error:', err);
        res.status(500).json({ error: 'Internal server error' });
    } finally {
        client.release();
    }
});

// Get payment history for the current user
const authMiddleware = require('../middleware/auth');
router.get('/payment-history', authMiddleware, async (req, res) => {
    try {
        const result = await db.query(
            `SELECT s.id, s.plan_id, s.store, s.expiry_date, s.created_at,
                    sp.name AS plan_name, sp.price_text, sp.period_text
             FROM subscriptions s
             LEFT JOIN subscription_plans sp ON sp.id = s.plan_id
             WHERE s.user_id = $1
             ORDER BY s.created_at DESC`,
            [req.userId]
        );
        res.json({ history: result.rows });
    } catch (err) {
        console.error('Payment history error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;
