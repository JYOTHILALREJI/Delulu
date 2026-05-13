const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const db = require('../db');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

const SALT_ROUNDS = 12;

// ── Register ──
router.post('/register', async (req, res) => {
  console.log(`[Auth] Register attempt for: ${req.body.email}`);
  try {
    const { email, password, display_name } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }
    if (password.length < 6) {
      return res
        .status(400)
        .json({ error: 'Password must be at least 6 characters' });
    }

    const existing = await db.query(
      'SELECT id FROM users WHERE email = $1',
      [email.toLowerCase()]
    );
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Email already registered' });
    }

    const hash = await bcrypt.hash(password, SALT_ROUNDS);

    const result = await db.query(
      'INSERT INTO users (email, password_hash, display_name, terms_accepted_at, privacy_accepted_at) VALUES ($1, $2, $3, NOW(), NOW()) RETURNING id, email, display_name, is_onboarded, created_at',
      [email.toLowerCase(), hash, display_name || '']
    );

    const user = result.rows[0];
    const token = jwt.sign(
      { userId: user.id },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.status(201).json({ token, user });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ── Login ──
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }

    const result = await db.query(
      'SELECT id, email, password_hash, display_name, is_onboarded, onboarding_step FROM users WHERE email = $1',
      [email.toLowerCase()]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const user = result.rows[0];
    const valid = await bcrypt.compare(password, user.password_hash);

    if (!valid) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const token = jwt.sign(
      { userId: user.id },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        display_name: user.display_name,
        is_onboarded: user.is_onboarded,
        onboarding_step: user.onboarding_step,
      },
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ── Get current user ──
router.get('/me', authMiddleware, async (req, res) => {
  try {
    const result = await db.query(
      `SELECT u.id, u.email, u.display_name, u.is_onboarded, u.onboarding_step, u.is_premium_user,
              u.attention_seeker_last_used, u.attention_seeker_free_used,
              p.display_name AS profile_name, p.age, p.gender, p.interested_in, p.bio, p.interests, p.photos,
              p.online_status_enabled, p.typing_indicator_enabled, p.last_seen_enabled, p.read_receipt_enabled,
              p.latitude, p.longitude, p.live_location_enabled, p.location_name, u.is_verified,
              p.is_premium, p.last_attention_seeker_at, p.e2e_encryption_enabled, p.hide_location_enabled,
              s.plan_id AS subscription_plan, s.expiry_date AS subscription_expiry
       FROM users u
       LEFT JOIN profiles p ON p.user_id = u.id
       LEFT JOIN subscriptions s ON s.user_id = u.id AND s.expiry_date > NOW()
       WHERE u.id = $1
       ORDER BY s.expiry_date DESC NULLS LAST LIMIT 1`,
      [req.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const row = result.rows[0];

    // Fetch connection count
    const connResult = await db.query(
      `SELECT COUNT(*) as count FROM connection_requests 
       WHERE (sender_id = $1 OR receiver_id = $1) AND status = 'accepted'`,
      [req.userId]
    );
    const connectCount = parseInt(connResult.rows[0].count);
    
    // Fetch likes count
    const likesResult = await db.query(
      `SELECT COUNT(*) as count FROM likes WHERE liked_user_id = $1`,
      [req.userId]
    );
    const likesCount = parseInt(likesResult.rows[0].count);

    // Calculate Aura Score (Matching %)
    let auraScore = 40; // Base
    if (row.bio && row.bio.length > 10) auraScore += 15;
    
    let interests = [];
    try {
      interests = typeof row.interests === 'string' ? JSON.parse(row.interests) : (row.interests || []);
    } catch (_) {}
    if (interests.length > 0) auraScore += 15;

    let photos = [];
    try {
      photos = typeof row.photos === 'string' ? JSON.parse(row.photos) : (row.photos || []);
    } catch (_) {}
    if (photos.length > 1) auraScore += 10;
    if (row.is_verified) auraScore += 5;

    // Connection bonus: 3% per connection, max 15%
    auraScore += Math.min(connectCount * 3, 15);
    
    // Cap at 100
    auraScore = Math.min(auraScore, 100);

    res.json({
      server_time: new Date().toISOString(),
      user: {
        id: row.id,
        email: row.email,
        display_name: row.profile_name || row.display_name || '',
        is_onboarded: row.is_onboarded,
        onboarding_step: row.onboarding_step,
        is_verified: row.is_verified,
        age: row.age,
        gender: row.gender,
        interested_in: row.interested_in,
        bio: row.bio,
        interests: row.interests,
        photos: row.photos,
        online_status_enabled: row.online_status_enabled,
        typing_indicator_enabled: row.typing_indicator_enabled,
        last_seen_enabled: row.last_seen_enabled,
        read_receipt_enabled: row.read_receipt_enabled,
        latitude: row.latitude,
        longitude: row.longitude,
        live_location_enabled: row.live_location_enabled,
        location_name: row.location_name,
        is_premium: row.is_premium,
        is_premium_user: row.is_premium_user,
        attention_seeker_last_used: row.attention_seeker_last_used,
        attention_seeker_free_used: row.attention_seeker_free_used,
        e2e_encryption_enabled: row.e2e_encryption_enabled,
        hide_location_enabled: row.hide_location_enabled,
        subscription_plan: row.subscription_plan,
        subscription_expiry: row.subscription_expiry,
        connect_count: connectCount,
        likes_count: likesCount,
        aura_score: auraScore
      },
    });
  } catch (err) {
    console.error('Get me error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/logout', authMiddleware, (req, res) => {
  res.json({ message: 'Logged out' });
});

// ── Update Password ──
router.put('/update-password', authMiddleware, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const userId = req.userId;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: 'Current and new password required' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ error: 'New password must be at least 6 characters' });
    }

    const result = await db.query('SELECT password_hash FROM users WHERE id = $1', [userId]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const user = result.rows[0];
    const valid = await bcrypt.compare(currentPassword, user.password_hash);

    if (!valid) {
      return res.status(401).json({ error: 'Invalid current password' });
    }

    const hash = await bcrypt.hash(newPassword, SALT_ROUNDS);
    await db.query('UPDATE users SET password_hash = $1 WHERE id = $2', [hash, userId]);

    res.json({ success: true, message: 'Password updated successfully' });
  } catch (err) {
    console.error('Update password error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ── Get Notification Counts ──
router.get('/notifications', authMiddleware, async (req, res) => {
  try {
    const userId = req.userId;

    // 1. Unread Messages
    const msgRes = await db.query(
      `SELECT COUNT(*)::int FROM messages m
       JOIN channels c ON m.channel_id = c.id
       WHERE (c.user1_id = $1 OR c.user2_id = $1)
         AND m.sender_id != $1
         AND m.read_at IS NULL`,
      [userId]
    );

    // 2. Pending Incoming Requests (Pings)
    const reqRes = await db.query(
      "SELECT COUNT(*)::int FROM connection_requests WHERE receiver_id = $1 AND status = 'pending'",
      [userId]
    );

    // 3. Pending Game Invites (Whispers)
    const gameRes = await db.query(
      "SELECT COUNT(*)::int FROM game_sessions WHERE receiver_id = $1 AND status = 'pending'",
      [userId]
    );

    res.json({
      unread_messages: msgRes.rows[0].count,
      pending_requests: reqRes.rows[0].count,
      pending_game_invites: gameRes.rows[0].count,
    });
  } catch (err) {
    console.error('Notification counts error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ── Delete Account ──
router.delete('/delete-account', authMiddleware, async (req, res) => {
  const client = await db.pool.connect();
  try {
    await client.query('BEGIN');
    // CASCADE deletes on profiles, likes, connection_requests etc. handled by DB constraints
    // Manually clean up tables without FK cascade to users
    await client.query('DELETE FROM subscriptions WHERE user_id = $1', [req.userId]);
    await client.query('DELETE FROM likes WHERE liker_id = $1 OR liked_user_id = $1', [req.userId]);
    await client.query('DELETE FROM connection_requests WHERE sender_id = $1 OR receiver_id = $1', [req.userId]);
    await client.query('DELETE FROM profiles WHERE user_id = $1', [req.userId]);
    await client.query('DELETE FROM users WHERE id = $1', [req.userId]);
    await client.query('COMMIT');
    res.json({ success: true, message: 'Account deleted successfully' });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Delete account error:', err);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    client.release();
  }
});

// ── Get Account Data ──
router.get('/account-data', authMiddleware, async (req, res) => {
  try {
    const userResult = await db.query(
      `SELECT u.id, u.email, u.display_name, u.is_onboarded, u.created_at, u.is_verified,
              p.display_name AS profile_name, p.age, p.gender, p.interested_in, p.bio,
              p.interests, p.photos, p.location_name, p.is_premium, p.premium_since
       FROM users u
       LEFT JOIN profiles p ON p.user_id = u.id
       WHERE u.id = $1`,
      [req.userId]
    );
    const subsResult = await db.query(
      'SELECT plan_id, store, expiry_date, created_at FROM subscriptions WHERE user_id = $1 ORDER BY created_at DESC',
      [req.userId]
    );
    if (userResult.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json({
      exported_at: new Date().toISOString(),
      user: userResult.rows[0],
      subscriptions: subsResult.rows,
    });
  } catch (err) {
    console.error('Account data error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;