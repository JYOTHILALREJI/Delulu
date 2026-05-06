const express = require('express');
const db = require('../db');
const socketManager = require('../socket');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// ── Save / Update Profile ──
router.put('/profile', authMiddleware, async (req, res) => {
  try {
    const userId = req.userId;
    const {
      display_name,
      age,
      gender,
      interested_in,
      bio,
      interests,
      photos,
      online_status_enabled,
      typing_indicator_enabled,
      last_seen_enabled,
      read_receipt_enabled,
      live_location_enabled,
      latitude,
      longitude,
      location_name,
      is_premium,
      is_verified
    } = req.body;

    console.log(`[Onboarding] Saving profile for user ${userId}.`);

    // Validate required fields (only if onboarding for the first time, but here we support partial updates too)
    // For simplicity, we'll keep the required checks if they are provided.

    // Upsert profile
    const result = await db.query(`
      UPDATE profiles
      SET 
        display_name = COALESCE($1, display_name),
        age = COALESCE($2, age),
        bio = COALESCE($3, bio),
        gender = COALESCE($4, gender),
        interested_in = COALESCE($5, interested_in),
        interests = COALESCE($6, interests),
        photos = COALESCE($7, photos),
        online_status_enabled = COALESCE($8, online_status_enabled),
        typing_indicator_enabled = COALESCE($9, typing_indicator_enabled),
        last_seen_enabled = COALESCE($10, last_seen_enabled),
        read_receipt_enabled = COALESCE($11, read_receipt_enabled),
        live_location_enabled = COALESCE($12, live_location_enabled),
        latitude = COALESCE($13, latitude),
        longitude = COALESCE($14, longitude),
        location_name = COALESCE($15, location_name),
        is_premium = COALESCE($16, is_premium),
        updated_at = CURRENT_TIMESTAMP
      WHERE user_id = $17
      RETURNING *
    `, [
      display_name, age, bio, gender, interested_in,
      interests ? JSON.stringify(interests) : null,
      photos ? JSON.stringify(photos) : null,
      online_status_enabled, typing_indicator_enabled,
      last_seen_enabled, read_receipt_enabled, live_location_enabled,
      latitude, longitude, location_name,
      is_premium,
      userId
    ]);

    // Update is_verified in users table if provided
    if (is_verified !== undefined) {
      await db.query('UPDATE users SET is_verified = $1 WHERE id = $2', [is_verified, userId]);
    }

    // Emit status change if visibility toggled
    const io = socketManager.getIo();
    if (online_status_enabled === false) {
      io.emit('user_status', { userId, status: 'offline' });
    } else if (online_status_enabled === true) {
      io.emit('user_status', { userId, status: 'online' });
    }

    // Mark user as onboarded
    await db.query(
      'UPDATE users SET is_onboarded = TRUE WHERE id = $1',
      [userId]
    );

    res.json({ success: true, message: 'Profile saved' });
  } catch (err) {
    console.error('Save profile error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;