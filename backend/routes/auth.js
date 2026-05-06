const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const db = require('../db');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

const SALT_ROUNDS = 12;

// ── Register ──
router.post('/register', async (req, res) => {
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
      'INSERT INTO users (email, password_hash, display_name) VALUES ($1, $2, $3) RETURNING id, email, display_name, is_onboarded, created_at',
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
      'SELECT id, email, password_hash, display_name, is_onboarded FROM users WHERE email = $1',
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
      `SELECT u.id, u.email, u.display_name, u.is_onboarded, u.created_at, u.is_verified,
              p.display_name AS profile_name, p.age, p.gender, p.interested_in, p.bio, p.interests, p.photos,
              p.online_status_enabled, p.typing_indicator_enabled, p.last_seen_enabled, p.read_receipt_enabled,
              p.latitude, p.longitude, p.live_location_enabled, p.location_name,
              p.is_premium, p.last_attention_seeker_at
       FROM users u
       LEFT JOIN profiles p ON p.user_id = u.id
       WHERE u.id = $1`,
      [req.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const row = result.rows[0];
    // Use profile_name if onboarded, otherwise use users.display_name
    res.json({
      user: {
        id: row.id,
        email: row.email,
        display_name: row.profile_name || row.display_name || '',
        is_onboarded: row.is_onboarded,
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
        last_attention_seeker_at: row.last_attention_seeker_at,
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

module.exports = router;