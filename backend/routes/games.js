const express = require('express');
const authMiddleware = require('../middleware/auth');
const db = require('../db');

const router = express.Router();

// Get all available games
router.get('/', authMiddleware, async (req, res) => {
  try {
    const result = await db.query('SELECT * FROM games WHERE active = TRUE ORDER BY created_at ASC');
    res.json({ games: result.rows });
  } catch (err) {
    console.error('Fetch games error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get game status for a specific channel (message count)
router.get('/status/:channelId', authMiddleware, async (req, res) => {
  try {
    const { channelId } = req.params;
    const userId = req.userId;

    // Verify user is in channel
    const channel = await db.query(
      'SELECT user1_id, user2_id FROM channels WHERE id = $1',
      [channelId]
    );

    if (channel.rows.length === 0) {
      return res.status(404).json({ error: 'Channel not found' });
    }

    const { user1_id, user2_id } = channel.rows[0];
    if (user1_id !== userId && user2_id !== userId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Count messages
    const msgCountRes = await db.query(
      'SELECT COUNT(*)::int FROM messages WHERE channel_id = $1',
      [channelId]
    );

    res.json({ 
      channelId: parseInt(channelId),
      messageCount: msgCountRes.rows[0].count 
    });
  } catch (err) {
    console.error('Game status error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
