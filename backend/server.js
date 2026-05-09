require('dotenv').config();
const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/auth');
const onboardingRoutes = require('./routes/onboarding');
const discoveryRoutes = require('./routes/discovery');
const likesRoutes = require('./routes/likes');
const requestsRoutes = require('./routes/requests');
const whispersRoutes = require('./routes/whispers');

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
  
  socket.join(userId);

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

  socket.on('typing', (data) => {
    // data: { channelId, peerId, isTyping }
    io.to(data.peerId).emit('typing_status', { 
      channelId: data.channelId, 
      userId: userId, 
      isTyping: data.isTyping 
    });
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
        const { last_attention_seeker_at, is_premium } = userRes.rows[0];
        if (last_attention_seeker_at) {
          const lastUse = new Date(last_attention_seeker_at);
          const now = new Date();
          const diffMs = now - lastUse;
          const cooldownMs = is_premium ? 30 * 60 * 1000 : 7 * 24 * 60 * 60 * 1000;
          
          if (diffMs < cooldownMs) {
            socket.emit('error_message', { 
              message: 'Attention Seeker is on cooldown',
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
      io.to(peerId).emit('attention_seeker_received', { fromId: userId });
    } catch (err) {
      console.error('Attention seeker error:', err);
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