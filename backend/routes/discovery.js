const express = require('express');
const authMiddleware = require('../middleware/auth');
const db = require('../db');

const router = express.Router();

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
    // Get current user's location
    const me = await db.query('SELECT latitude, longitude FROM profiles WHERE user_id = $1', [req.userId]);
    const myLat = me.rows[0]?.latitude;
    const myLng = me.rows[0]?.longitude;

    const result = await db.query(`
      SELECT
        u.id as id,
        u.is_verified,
        p.display_name,
        p.age,
        p.gender,
        p.interested_in,
        p.bio,
        p.interests,
        p.photos,
        p.latitude,
        p.longitude,
        p.live_location_enabled,
        EXISTS(SELECT 1 FROM likes WHERE liker_user_id = $1 AND liked_user_id = u.id) as is_liked,
        (SELECT status FROM connection_requests 
         WHERE (sender_id = $1 AND receiver_id = u.id) 
            OR (sender_id = u.id AND receiver_id = $1)
         ORDER BY (status = 'accepted') DESC, created_at DESC LIMIT 1) as request_status,
        (SELECT id FROM channels 
         WHERE (user1_id = $1 AND user2_id = u.id) 
            OR (user1_id = u.id AND user2_id = $1) LIMIT 1) as channel_id
      FROM profiles p
      JOIN users u ON p.user_id = u.id
      WHERE u.id != $1
        AND u.is_onboarded = TRUE
      ORDER BY RANDOM()
      LIMIT 20
    `, [req.userId]);

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

      // Calculate distance if both have location
      let distance = null;
      if (myLat && myLng && row.latitude && row.longitude && row.live_location_enabled) {
        // Simple Haversine approximation
        const R = 3958.8; // Miles
        const dLat = (row.latitude - myLat) * Math.PI / 180;
        const dLon = (row.longitude - myLng) * Math.PI / 180;
        const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
          Math.cos(myLat * Math.PI / 180) * Math.cos(row.latitude * Math.PI / 180) *
          Math.sin(dLon / 2) * Math.sin(dLon / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        distance = Math.round(R * c);
      }

      // If no photos uploaded, assign placeholders
      if (photos.length === 0) {
        photos = getPlaceholderPhotos(row.gender || 'Non-Binary', 3);
      }

      return {
        ...row,
        photos,
        interests,
        distance
      };
    });

    return res.json({ profiles: profiles });
  } catch (err) {
    console.error('Discovery feed error:', err);
    res.status(500).json({ error: 'Failed to load feed' });
  }
});

module.exports = router;