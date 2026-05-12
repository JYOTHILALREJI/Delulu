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

    // Find active/accepted session for this channel
    const sessionRes = await db.query(
      `SELECT id, status, state FROM game_sessions
       WHERE channel_id = $1 AND (inviter_id = $2 OR receiver_id = $2)
         AND status IN ('accepted', 'pending')
       ORDER BY created_at DESC LIMIT 1`,
      [channelId, userId]
    );

    // Count ALL messages in this channel (sent + received)
    const msgCountRes = await db.query(
      'SELECT COUNT(*)::int as count FROM messages WHERE channel_id = $1',
      [channelId]
    );

    const messageCount = msgCountRes.rows[0].count;
    const sessionId = sessionRes.rows[0]?.id || null;
    const status = sessionRes.rows[0]?.status || null;

    console.log(`[GameStatus] Channel: ${channelId}, Messages: ${messageCount}, Session: ${sessionId}, Status: ${status}`);

    res.json({
      channelId: parseInt(channelId),
      messageCount: parseInt(messageCount),
      sessionId: sessionId,
      status: status,
    });
  } catch (err) {
    console.error('Game status error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get current game session state
router.get('/session/:sessionId', authMiddleware, async (req, res) => {
  try {
    const { sessionId } = req.params;
    const userId = req.userId;

    const result = await db.query(
      'SELECT id, inviter_id, receiver_id, game_id, game_name, status, state, created_at, updated_at FROM game_sessions WHERE id = $1',
      [sessionId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Session not found' });
    }
    const session = result.rows[0];
    if (session.inviter_id !== userId && session.receiver_id !== userId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    res.json({ session });
  } catch (err) {
    console.error('Get game session error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get game messages for a session
router.get('/session/:sessionId/messages', authMiddleware, async (req, res) => {
  try {
    const { sessionId } = req.params;
    const userId = req.userId;

    const sessionRes = await db.query(
      'SELECT inviter_id, receiver_id FROM game_sessions WHERE id = $1',
      [sessionId]
    );
    if (sessionRes.rows.length === 0) {
      return res.status(404).json({ error: 'Session not found' });
    }
    const { inviter_id, receiver_id } = sessionRes.rows[0];
    if (inviter_id !== userId && receiver_id !== userId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    const result = await db.query(
      'SELECT id, session_id, sender_id, content, message_type, created_at FROM game_messages WHERE session_id = $1 ORDER BY created_at ASC',
      [sessionId]
    );

    res.json({ messages: result.rows });
  } catch (err) {
    console.error('Get game messages error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get how many times current user played a game today (for free play limit)
router.get('/plays/today/:gameId', authMiddleware, async (req, res) => {
  try {
    const { gameId } = req.params;
    const userId = req.userId;
    const result = await db.query(
      `SELECT COUNT(*)::int AS count FROM game_plays
       WHERE user_id = $1 AND game_id = $2
         AND played_at >= NOW()::date`,
      [userId, gameId]
    );
    res.json({ count: result.rows[0].count });
  } catch (err) {
    console.error('Get today plays error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Record a game play (called when invite is sent)
router.post('/plays/:gameId', authMiddleware, async (req, res) => {
  try {
    const { gameId } = req.params;
    const userId = req.userId;
    const { channelId } = req.body;
    await db.query(
      `INSERT INTO game_plays (user_id, game_id, channel_id) VALUES ($1, $2, $3)`,
      [userId, gameId, channelId || null]
    );
    res.json({ ok: true });
  } catch (err) {
    console.error('Record play error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
