require('dotenv').config();
const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/auth');
const onboardingRoutes = require('./routes/onboarding');
const discoveryRoutes = require('./routes/discovery');
const likesRoutes = require('./routes/likes');
const requestsRoutes = require('./routes/requests');
const whispersRoutes = require('./routes/whispers');
const gamesRoutes = require('./routes/games');
const premiumRoutes = require('./routes/premium');

const http = require('http');
const socketManager = require('./socket');
const jwt = require('jsonwebtoken');
const onlineTracker = require('./online_tracker');
const db = require('./db');

const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 3000;

// ── Socket.IO Setup ──
const io = socketManager.init(server);

io.use((socket, next) => {
  const token = socket.handshake.auth.token;
  if (!token) return next(new Error('Auth error'));

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    socket.userId = decoded.userId;
    next();
  } catch (err) {
    next(new Error('Auth error'));
  }
});

io.on('connection', async (socket) => {
  const userId = socket.userId;
  console.log(`User connected to socket: ${userId}`);

  socket.join(userId.toString());

  // Fetch privacy settings
  let onlineEnabled = true;
  try {
    const res = await db.query('SELECT online_status_enabled FROM profiles WHERE user_id = $1', [userId]);
    if (res.rows.length > 0) {
      onlineEnabled = res.rows[0].online_status_enabled !== false;
    }
  } catch (err) {
    console.error('Error fetching privacy settings:', err);
  }

  // Track online status
  if (onlineTracker.addSocket(userId, socket.id)) {
    if (onlineEnabled) {
      io.emit('user_status', { userId, status: 'online' });
    }
  }

  socket.on('typing', async (data) => {
    // data: { channelId, peerId, isTyping }
    try {
      const res = await db.query('SELECT typing_indicator_enabled FROM profiles WHERE user_id = $1', [userId]);
      if (res.rows.length > 0 && res.rows[0].typing_indicator_enabled === false) {
        return; // Don't broadcast if disabled
      }
      io.to(data.peerId.toString()).emit('typing_status', {
        channelId: data.channelId,
        userId: userId,
        isTyping: data.isTyping
      });
    } catch (err) {}
  });

  socket.on('attention_seeker', async (data) => {
    const { peerId } = data;
    if (!userId || !peerId) return;

    // Check if peer is online
    if (!onlineTracker.isOnline(peerId)) {
      socket.emit('error_message', { message: 'User is not online' });
      return;
    }

    try {
      // Fetch user's last use and premium status
      const userRes = await db.query(
        'SELECT last_attention_seeker_at, is_premium FROM profiles WHERE user_id = $1',
        [userId]
      );

      if (userRes.rows.length > 0) {
        const profile = userRes.rows[0];
        if (profile.last_attention_seeker_at) {
          if (!profile.is_premium) {
            socket.emit('error_message', {
              message: 'Attention Seeker is a Premium feature after your first use. Upgrade to Rizz+ to continue!',
              type: 'attention_premium_required'
            });
            return;
          }

          const lastUse = new Date(profile.last_attention_seeker_at);
          const now = new Date();
          const diffMs = now - lastUse;
          const cooldownMs = 15 * 60 * 1000; // 15 minutes for Premium

          if (diffMs < cooldownMs) {
            socket.emit('error_message', {
              message: 'Attention Seeker is on cooldown. Please wait before seeking attention again.',
              type: 'attention_cooldown'
            });
            return;
          }
        }
      }

      console.log(`Attention seeker from ${userId} to ${peerId}`);

      // Update last use in DB
      await db.query(
        'UPDATE profiles SET last_attention_seeker_at = NOW() WHERE user_id = $1',
        [userId]
      );

      // Relay to peer
      io.to(peerId.toString()).emit('attention_seeker_received', { fromId: userId });
    } catch (err) {
      console.error('Attention seeker error:', err);
    }
  });

  socket.on('game_invite', async (data) => {
    // data: { channelId, peerId, gameId, gameName }
    const { channelId, peerId, gameId, gameName } = data;
    try {
      // 1. Check if game is premium
      const gameRes = await db.query('SELECT is_premium FROM games WHERE id = $1', [gameId]);
      const isPremiumGame = gameRes.rows[0]?.is_premium === true;

      // 2. Check if inviter is premium
      const inviterRes = await db.query(
        'SELECT display_name, is_premium FROM profiles WHERE user_id = $1',
        [userId]
      );
      const isInviterPremium = inviterRes.rows[0]?.is_premium === true;
      const fromName = inviterRes.rows[0]?.display_name || 'Partner';

      // 3. Enforce rules
      if (isPremiumGame && !isInviterPremium) {
        socket.emit('error_message', {
          message: 'Upgrade to Rizz+ to invite to premium games',
          type: 'premium_required'
        });
        return;
      }

      const res = await db.query(
        'INSERT INTO game_sessions (channel_id, inviter_id, receiver_id, game_id, game_name, status) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id',
        [channelId, userId, peerId, gameId, gameName, 'pending']
      );
      const sessionId = res.rows[0].id;

      socket.emit('game_invite_sent', { sessionId, fromName, ...data });

      io.to(peerId.toString()).emit('game_invite_received', {
        ...data,
        sessionId,
        fromName,
        fromId: userId
      });
    } catch (err) {
      console.error('Game invite error:', err);
    }
  });

  socket.on('game_invite_response', async (data) => {
    // data: { channelId, peerId, sessionId, accepted }
    const { channelId, peerId, sessionId, accepted } = data;
    const status = accepted ? 'accepted' : 'rejected';

    try {
      const sessionCheck = await db.query('SELECT game_id, game_name FROM game_sessions WHERE id = $1', [sessionId]);
      const gameId = sessionCheck.rows[0]?.game_id;
      const gameName = sessionCheck.rows[0]?.game_name;

      await db.query(
        'UPDATE game_sessions SET status = $1, updated_at = NOW() WHERE id = $2',
        [status, sessionId]
      );

      // Create a status message in the chat
      const msgRes = await db.query(
        'INSERT INTO messages (channel_id, sender_id, content, message_type) VALUES ($1, $2, $3, $4) RETURNING *',
        [channelId, userId, JSON.stringify({ sessionId, status, gameId, gameName }), 'game_status']
      );

      io.to(peerId.toString()).emit('game_invite_response_received', {
        ...data,
        status,
        fromId: userId
      });

      // Broadcast new message to both
      io.to(userId.toString()).to(peerId.toString()).emit('new_message', msgRes.rows[0]);
    } catch (err) {
      console.error('Game response error:', err);
    }
  });

  socket.on('game_cancel', async (data) => {
    // data: { sessionId, peerId, channelId }
    const { sessionId, peerId, channelId } = data;
    let actualSessionId = sessionId;
    try {
      if (!actualSessionId) {
        // Find latest pending session for this channel/user if sessionId not yet known
        const pendingCheck = await db.query(
          'SELECT id FROM game_sessions WHERE channel_id = $1 AND inviter_id = $2 AND status = $3 ORDER BY created_at DESC LIMIT 1',
          [channelId, userId, 'pending']
        );
        if (pendingCheck.rows.length > 0) {
          actualSessionId = pendingCheck.rows[0].id;
        } else {
          return;
        }
      }

      const sessionCheck = await db.query('SELECT game_id, game_name FROM game_sessions WHERE id = $1', [actualSessionId]);
      const gameId = sessionCheck.rows[0]?.game_id;
      const gameName = sessionCheck.rows[0]?.game_name;

      await db.query(
        'UPDATE game_sessions SET status = $1, updated_at = NOW() WHERE id = $2',
        ['cancelled', actualSessionId]
      );

      const msgRes = await db.query(
        'INSERT INTO messages (channel_id, sender_id, content, message_type) VALUES ($1, $2, $3, $4) RETURNING *',
        [channelId, userId, JSON.stringify({ sessionId: actualSessionId, status: 'cancelled', gameId, gameName }), 'game_status']
      );

      io.to(peerId.toString()).emit('game_cancelled', { sessionId: actualSessionId });
      io.to(userId.toString()).to(peerId.toString()).emit('new_message', msgRes.rows[0]);
    } catch (err) {
      console.error('Game cancel error:', err);
    }
  });

  socket.on('game_session_update', async (data) => {
    // data: { sessionId, duration }
    const { sessionId, duration } = data;
    try {
      await db.query(
        'UPDATE game_sessions SET duration = $1, status = $2, updated_at = NOW() WHERE id = $3',
        [duration, 'completed', sessionId]
      );
    } catch (err) {
      console.error('Game session update error:', err);
    }
  });

  socket.on('disconnect', async () => {
    console.log(`User disconnected from socket: ${userId}`);
    if (onlineTracker.removeSocket(userId, socket.id)) {
      io.emit('user_status', { userId, status: 'offline' });
      // Update last seen
      try {
        await db.query('UPDATE profiles SET last_seen_at = NOW() WHERE user_id = $1', [userId]);
      } catch (err) {
        console.error('Error updating last seen:', err);
      }
    }
  });
});

// ── Middleware ──
app.use(cors({
  origin: '*', // Allow all origins for development
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json({ limit: '50mb' }));

// ── Routes ──
app.use('/api/auth', authRoutes);
app.use('/api/onboarding', onboardingRoutes);
app.use('/api/discovery', discoveryRoutes);
app.use('/api/likes', likesRoutes);
app.use('/api/requests', requestsRoutes);
app.use('/api/whispers', whispersRoutes);
app.use('/api/games', gamesRoutes);
app.use('/api/premium', premiumRoutes);

// ── Health Check ──
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.get('/api/version', (req, res) => {
  const pkg = require('./package.json');
  res.json({ version: pkg.version });
});

// ── Global Error Handler ──
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// ── Start ──
server.listen(PORT, '0.0.0.0', () => {
  console.log(`\n  Delulu API running on http://0.0.0.0:${PORT}`);
  console.log(`  Health: http://localhost:${PORT}/api/health\n`);
});
