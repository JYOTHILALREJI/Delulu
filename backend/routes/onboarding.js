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

    console.log(`[Onboarding] Saving profile for user ${userId}. Keys:`, Object.keys(req.body));
    if (req.body.photos) {
      console.log(`[Onboarding] Photos received: ${req.body.photos.length} items`);
      console.log(`[Onboarding] First photo primary: ${req.body.photos[0]?.is_primary}`);
    }

    // Validate required fields (only if onboarding for the first time, but here we support partial updates too)
    // For simplicity, we'll keep the required checks if they are provided.

    // Upsert profile
    const result = await db.query(`
      INSERT INTO profiles (
        user_id, 
        display_name, 
        age, 
        bio, 
        gender, 
        interested_in, 
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
        is_premium
      ) VALUES (
        $17, 
        COALESCE($1, ''), 
        COALESCE($2, 18), 
        COALESCE($3, ''), 
        COALESCE($4, ''), 
        COALESCE($5, ''), 
        COALESCE($6, '[]')::jsonb, 
        COALESCE($7, '[]')::jsonb, 
        COALESCE($8, TRUE), 
        COALESCE($9, TRUE), 
        COALESCE($10, TRUE), 
        COALESCE($11, TRUE), 
        COALESCE($12, FALSE), 
        $13, 
        $14, 
        $15, 
        COALESCE($16, FALSE)
      )
      ON CONFLICT (user_id) DO UPDATE SET
        display_name = COALESCE($1, profiles.display_name),
        age = COALESCE($2, profiles.age),
        bio = COALESCE($3, profiles.bio),
        gender = COALESCE($4, profiles.gender),
        interested_in = COALESCE($5, profiles.interested_in),
        interests = COALESCE($6::jsonb, profiles.interests),
        photos = COALESCE($7::jsonb, profiles.photos),
        online_status_enabled = COALESCE($8, profiles.online_status_enabled),
        typing_indicator_enabled = COALESCE($9, profiles.typing_indicator_enabled),
        last_seen_enabled = COALESCE($10, profiles.last_seen_enabled),
        read_receipt_enabled = COALESCE($11, profiles.read_receipt_enabled),
        live_location_enabled = COALESCE($12, profiles.live_location_enabled),
        latitude = COALESCE($13, profiles.latitude),
        longitude = COALESCE($14, profiles.longitude),
        location_name = COALESCE($15, profiles.location_name),
        is_premium = COALESCE($16, profiles.is_premium),
        updated_at = CURRENT_TIMESTAMP
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
    
    console.log(`[Onboarding] Profile UPSERT completed. Rows affected: ${result.rowCount}`);

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
    console.error('[Onboarding] Save profile error:', err);
    res.status(500).json({ error: 'Internal server error', details: err.message });
  }
});

module.exports = router;
