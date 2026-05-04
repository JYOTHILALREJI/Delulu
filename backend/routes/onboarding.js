const express = require('express');
const db = require('../db');
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
    } = req.body;

    // Validate required fields
    if (!display_name || !age || !gender || !interested_in) {
      return res.status(400).json({
        error: 'display_name, age, gender, and interested_in are required',
      });
    }

    if (age < 13 || age > 120) {
      return res
        .status(400)
        .json({ error: 'Age must be between 13 and 120' });
    }

    const validGenders = ['Non-Binary', 'Woman', 'Man'];
    if (!validGenders.includes(gender)) {
      return res
        .status(400)
        .json({ error: 'Gender must be Non-Binary, Woman, or Man' });
    }

    const validSeeking = ['Everyone', 'Women', 'Men'];
    if (!validSeeking.includes(interested_in)) {
      return res
        .status(400)
        .json({ error: 'interested_in must be Everyone, Women, or Men' });
    }

    // Upsert profile
    await db.query(
      `INSERT INTO profiles (user_id, display_name, age, gender, interested_in, bio, interests, photos)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (user_id) DO UPDATE SET
         display_name = EXCLUDED.display_name,
         age = EXCLUDED.age,
         gender = EXCLUDED.gender,
         interested_in = EXCLUDED.interested_in,
         bio = EXCLUDED.bio,
         interests = EXCLUDED.interests,
         photos = EXCLUDED.photos,
         updated_at = NOW()`,
      [
        userId,
        display_name,
        age,
        gender,
        interested_in,
        bio || '',
        JSON.stringify(interests || []),
        JSON.stringify(photos || []),
      ]
    );

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