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
    const result = await db.query(`
      SELECT
        u.id as id,
        p.display_name,
        p.age,
        p.gender,
        p.interested_in,
        p.bio,
        p.interests,
        p.photos,
        p.latitude,
        p.longitude,
        EXISTS(SELECT 1 FROM likes WHERE liker_user_id = $1 AND liked_user_id = u.id) as is_liked
      FROM profiles p
      JOIN users u ON p.user_id = u.id
      WHERE u.id != $1
        AND u.is_onboarded = TRUE
      ORDER BY RANDOM()
      LIMIT 20
    `, [req.userId]);

    console.log(`Discovery feed: found ${result.rows.length} profiles for user ${req.userId}`);

      // Process profiles: add placeholder photos if empty
      const profiles = result.rows.map(row => {
        let photos = [];
        if (row.photos) {
          if (typeof row.photos === 'string') {
            try {
              photos = JSON.parse(row.photos);
            } catch (_) {
              photos = [];
            }
          } else {
            photos = row.photos;
          }
        }

        console.log(`  Profile ${row.display_name}: ${photos.length} photos found in DB`);

      // If no photos uploaded, assign placeholders
      if (photos.length === 0) {
        photos = getPlaceholderPhotos(row.gender || 'Non-Binary', 3);
      }

      return {
        ...row,
        photos
      };
    });

    return res.json({ profiles: profiles });
  } catch (err) {
    console.error('Discovery feed error:', err);
    res.status(500).json({ error: 'Failed to load feed' });
  }
});

module.exports = router;