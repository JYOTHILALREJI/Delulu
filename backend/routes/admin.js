const express = require('express');
const authMiddleware = require('../middleware/auth');
const db = require('../db');

const router = express.Router();

// Middleware to ensure the user is an admin
const adminMiddleware = async (req, res, next) => {
  try {
    const result = await db.query('SELECT is_admin FROM users WHERE id = $1', [req.userId]);
    if (result.rows.length === 0 || !result.rows[0].is_admin) {
      return res.status(403).json({ error: 'Access denied. Admins only.' });
    }
    next();
  } catch (err) {
    console.error('Admin middleware error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// ── Get all reports ──
router.get('/reports', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await db.query(`
      SELECT 
        r.id, r.reason, r.created_at,
        u1.email as reporter_email, u1.display_name as reporter_name,
        u2.id as reported_id, u2.email as reported_email, u2.display_name as reported_name, u2.is_blocked
      FROM reports r
      JOIN users u1 ON r.reporter_id = u1.id
      JOIN users u2 ON r.reported_id = u2.id
      ORDER BY r.created_at DESC
    `);
    res.json({ reports: result.rows });
  } catch (err) {
    console.error('Fetch reports error:', err);
    res.status(500).json({ error: 'Failed to fetch reports' });
  }
});

// ── Block/Unblock User ──
router.post('/block-user', authMiddleware, adminMiddleware, async (req, res) => {
  const { userId, block } = req.body; // block is a boolean
  if (!userId) return res.status(400).json({ error: 'User ID required' });

  const client = await db.pool.connect();
  try {
    await client.query('BEGIN');
    
    // Update users table
    await client.query('UPDATE users SET is_blocked = $1 WHERE id = $2', [block, userId]);
    
    // Update profiles table
    await client.query('UPDATE profiles SET is_blocked = $1 WHERE user_id = $2', [block, userId]);
    
    await client.query('COMMIT');
    res.json({ success: true, message: `User ${block ? 'blocked' : 'unblocked'} successfully` });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Block user error:', err);
    res.status(500).json({ error: 'Failed to update block status' });
  } finally {
    client.release();
  }
});

// ── Get User Details (Admin) ──
router.get('/user/:userId', authMiddleware, adminMiddleware, async (req, res) => {
    try {
      const result = await db.query(`
        SELECT u.id, u.email, u.display_name, u.is_onboarded, u.is_admin, u.is_blocked, u.created_at,
               p.age, p.gender, p.bio, p.photos
        FROM users u
        LEFT JOIN profiles p ON p.user_id = u.id
        WHERE u.id = $1
      `, [req.params.userId]);
  
      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'User not found' });
      }
  
      res.json({ user: result.rows[0] });
    } catch (err) {
      console.error('Admin get user error:', err);
      res.status(500).json({ error: 'Internal server error' });
    }
  });

// ── Get Support Queries (Admin) ──
router.get('/support-queries', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await db.query(`
      SELECT id, user_id, email, name, query, status, created_at
      FROM support_queries
      ORDER BY created_at DESC
    `);
    res.json({ queries: result.rows });
  } catch (err) {
    console.error('Fetch support queries error:', err);
    res.status(500).json({ error: 'Failed to fetch support queries' });
  }
});

module.exports = router;
