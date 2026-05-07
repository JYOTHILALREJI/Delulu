const express = require('express');
const authMiddleware = require('../middleware/auth');
const db = require('../db');

const router = express.Router();
const MILES_TO_METERS = 1609.34;

// ── Get discovery stats (age range) ──
router.get('/stats', authMiddleware, async (req, res) => {
  try {
    const result = await db.query('SELECT MIN(age) as min_age, MAX(age) as max_age FROM profiles');
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch stats' });
  }
});

// Placeholder photo generator based on gender for users who haven't uploaded
function getPlaceholderPhotos(gender, count) {
  const female = [
    'https://images.unsplash.com/photo-1494790108377-be9c29129630?w=800&q=80',
    'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=800&q=80',
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=80',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=800&q=80',
  ];
  const male = [
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=80',
    'https://images.unsplash.com/photo-1494790108377-be9c29129630?w=800&q=80',
    'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&q=80',
  ];
  const others = [
    'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=800&q=80',
    'https://images.unsplash.com/photo-1524250502761-2ac926805f23?w=800&q=80',
  ];

  let pool;
  if (gender === 'Woman') pool = female;
  else if (gender === 'Man') pool = male;
  else pool = others;

  const shuffled = [...pool].sort(() => 0.5 - Math.random());
  return shuffled.slice(0, count).map(url => ({ url, is_private: false }));
}

router.get('/feed', authMiddleware, async (req, res) => {
  try {
    const userId = req.userId;
    const { age_min, age_max, distance_miles, limit = 10, offset = 0 } = req.query;

    const isManualFilter = age_min || age_max || (distance_miles && distance_miles < 100);

    // 1. Get current user profile
    const meRes = await db.query(
      'SELECT gender, interested_in, interests, latitude, longitude FROM profiles WHERE user_id = $1',
      [userId]
    );
    const me = meRes.rows[0];
    if (!me) return res.status(404).json({ error: 'Profile not found' });

    const myInterests = Array.isArray(me.interests) ? me.interests : [];
    const myLat = me.latitude;
    const myLng = me.longitude;

    // 2. Build Gender Filter
    let genderFilter = '';
    if (me.interested_in === 'Women') {
      genderFilter = "AND p.gender = 'Woman'";
    } else if (me.interested_in === 'Men') {
      genderFilter = "AND p.gender = 'Man'";
    }

    // 3. Handle Manual Filter Mode
    if (isManualFilter) {
      let ageFilter = '';
      if (age_min && age_max) {
        ageFilter = `AND p.age BETWEEN ${parseInt(age_min)} AND ${parseInt(age_max)}`;
      }

      let distanceFilter = '';
      if (distance_miles && myLat && myLng) {
        distanceFilter = `AND (
          3958.8 * acos(
            cos(radians(${myLat})) * cos(radians(p.latitude)) * 
            cos(radians(p.longitude) - radians(${myLng})) + 
            sin(radians(${myLat})) * sin(radians(p.latitude))
          )
        ) <= ${parseFloat(distance_miles)}`;
      }

      const result = await db.query(`
        SELECT
          u.id, u.is_verified, p.display_name, p.age, p.gender, p.interested_in, p.bio, p.interests, p.photos, p.latitude, p.longitude, p.live_location_enabled,
          EXISTS(SELECT 1 FROM likes WHERE liker_user_id = $1 AND liked_user_id = u.id) as is_liked,
          (SELECT status FROM connection_requests WHERE (sender_id = $1 AND receiver_id = u.id) OR (sender_id = u.id AND receiver_id = $1) ORDER BY (status = 'accepted') DESC, created_at DESC LIMIT 1) as request_status,
          (SELECT id FROM channels WHERE (user1_id = $1 AND user2_id = u.id) OR (user1_id = u.id AND user2_id = $1) LIMIT 1) as channel_id
        FROM profiles p
        JOIN users u ON p.user_id = u.id
        WHERE u.id != $1
          AND u.is_onboarded = TRUE
          ${genderFilter}
          ${ageFilter}
          ${distanceFilter}
          AND NOT EXISTS (SELECT 1 FROM connection_requests WHERE ((sender_id = $1 AND receiver_id = u.id) OR (sender_id = u.id AND receiver_id = $1)) AND status = 'accepted')
          AND NOT EXISTS (SELECT 1 FROM blocks WHERE (blocker_id = $1 AND blocked_id = u.id) OR (blocker_id = u.id AND blocked_id = $1))
        ORDER BY p.user_id
        LIMIT $2 OFFSET $3
      `, [userId, parseInt(limit), parseInt(offset)]);

      const profiles = result.rows.map(row => {
        const parseJson = (val) => {
          if (!val) return [];
          if (typeof val === 'string') {
            try { return JSON.parse(val); } catch (_) { return []; }
          }
          return val;
        };
        let interests = parseJson(row.interests);
        let photos = parseJson(row.photos);
        if (photos.length === 0) photos = getPlaceholderPhotos(row.gender || 'Non-Binary', 3);
        const commonInterests = interests.filter(i => myInterests.includes(i));
        return { ...row, photos, interests, commonInterests };
      });

      return res.json({ profiles });
    }

    // 4. Default Mode (Interest Based)
    const interestsQueryPart = myInterests.length > 0 
      ? `AND p.interests ?| array[${myInterests.map(i => `'${i}'`).join(',')}]`
      : 'AND FALSE';

    const result = await db.query(`
      SELECT
        u.id, u.is_verified, p.display_name, p.age, p.gender, p.interested_in, p.bio, p.interests, p.photos, p.latitude, p.longitude, p.live_location_enabled,
        EXISTS(SELECT 1 FROM likes WHERE liker_user_id = $1 AND liked_user_id = u.id) as is_liked,
        (SELECT status FROM connection_requests WHERE (sender_id = $1 AND receiver_id = u.id) OR (sender_id = u.id AND receiver_id = $1) ORDER BY (status = 'accepted') DESC, created_at DESC LIMIT 1) as request_status,
        (SELECT id FROM channels WHERE (user1_id = $1 AND user2_id = u.id) OR (user1_id = u.id AND user2_id = $1) LIMIT 1) as channel_id
      FROM profiles p
      JOIN users u ON p.user_id = u.id
      WHERE u.id != $1
        AND u.is_onboarded = TRUE
        ${genderFilter}
        AND ((${interestsQueryPart}) OR TRUE) -- Fallback to all if interests mode is off
        AND NOT EXISTS (SELECT 1 FROM connection_requests WHERE ((sender_id = $1 AND receiver_id = u.id) OR (sender_id = u.id AND receiver_id = $1)) AND status = 'accepted')
        AND NOT EXISTS (SELECT 1 FROM blocks WHERE (blocker_id = $1 AND blocked_id = u.id) OR (blocker_id = u.id AND blocked_id = $1))
      ORDER BY p.user_id
      LIMIT $2 OFFSET $3
    `, [userId, parseInt(limit), parseInt(offset)]);

    const profiles = result.rows.map(row => {
      const parseJson = (val) => {
        if (!val) return [];
        if (typeof val === 'string') {
          try { return JSON.parse(val); } catch (_) { return []; }
        }
        return val;
      };

      let photos = parseJson(row.photos);
      let interests = parseJson(row.interests);
      const commonInterests = interests.filter(i => myInterests.includes(i));
      if (photos.length === 0) photos = getPlaceholderPhotos(row.gender || 'Non-Binary', 3);

      return { ...row, photos, interests, commonInterests };
    });

    res.json({ profiles });
  } catch (err) {
    console.error('Discovery feed error:', err);
    res.status(500).json({ error: 'Failed to load feed' });
  }
});

router.get('/profile/:userId', authMiddleware, async (req, res) => {
  try {
    const targetUserId = req.params.userId;
    const currentUserId = req.userId;

    const result = await db.query(`
      SELECT
        u.id, u.is_verified, p.display_name, p.age, p.gender, p.interested_in, p.bio, p.interests, p.photos,
        EXISTS(SELECT 1 FROM likes WHERE liker_user_id = $2 AND liked_user_id = u.id) as is_liked,
        EXISTS(SELECT 1 FROM blocks WHERE blocker_id = $2 AND blocked_id = u.id) as is_blocked,
        (SELECT status FROM connection_requests WHERE (sender_id = $2 AND receiver_id = u.id) OR (sender_id = u.id AND receiver_id = $2) ORDER BY (status = 'accepted') DESC, created_at DESC LIMIT 1) as request_status
      FROM profiles p
      JOIN users u ON p.user_id = u.id
      WHERE u.id = $1
    `, [targetUserId, currentUserId]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const row = result.rows[0];

    // Connection count for target user
    const connRes = await db.query(
      `SELECT COUNT(*) as count FROM connection_requests 
       WHERE (sender_id = $1 OR receiver_id = $1) AND status = 'accepted'`,
      [targetUserId]
    );
    const connectCount = parseInt(connRes.rows[0].count);

    // Calculate Aura Score (Matching %) for target user
    let auraScore = 40; 
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
    auraScore += Math.min(connectCount * 3, 15);
    auraScore = Math.min(auraScore, 100);

    const parseJson = (val) => {
      if (!val) return [];
      if (typeof val === 'string') {
        try { return JSON.parse(val); } catch (_) { return []; }
      }
      return val;
    };

    res.json({
      profile: {
        ...row,
        interests: parseJson(row.interests),
        photos: parseJson(row.photos),
        connect_count: connectCount,
        aura_score: auraScore
      }
    });
  } catch (err) {
    console.error('Public profile error:', err);
    res.status(500).json({ error: 'Failed to load profile' });
  }
});

module.exports = router;