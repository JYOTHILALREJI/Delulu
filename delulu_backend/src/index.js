const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const { createClient } = require('@supabase/supabase-js');
const { RtcTokenBuilder, RtcRole } = require('agora-access-token');
const multer = require('multer');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { v4: uuidv4 } = require('uuid');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);

// Cloudflare R2 config (S3-compatible)
const r2 = new S3Client({
  region: 'auto',
  endpoint: process.env.R2_ENDPOINT,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY,
    secretAccessKey: process.env.R2_SECRET_KEY,
  },
});

const upload = multer({ storage: multer.memoryStorage() });

// Store socket IDs for users
const userSockets = new Map();

// ---------- Socket.IO logic ----------
io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  socket.on('register_user', (userId) => {
    userSockets.set(userId, socket.id);
    socket.join(`user_${userId}`);
    console.log(`User ${userId} registered with socket ${socket.id}`);
  });

  socket.on('join_chat', (roomId) => {
    socket.join(roomId);
    console.log(`Socket ${socket.id} joined room ${roomId}`);
  });

  socket.on('send_message', async (data) => {
    const { roomId, message, userId } = data;
    // Store in Supabase
    await supabase.from('messages').insert({
      room_id: roomId,
      sender_id: userId,
      content: message,
      created_at: new Date().toISOString(),
    });
    io.to(roomId).emit('new_message', {
      content: message,
      sender_id: userId,
      created_at: new Date().toISOString(),
    });
  });

  // Attention Seeker events
  socket.on('attention_start', ({ toUserId }) => {
    const targetSocketId = userSockets.get(toUserId);
    if (targetSocketId) {
      io.to(targetSocketId).emit('attention_vibrate');
      console.log(`Attention start sent to ${toUserId}`);
    }
  });

  socket.on('attention_stop', ({ toUserId }) => {
    const targetSocketId = userSockets.get(toUserId);
    if (targetSocketId) {
      io.to(targetSocketId).emit('attention_stop_vibrate');
      console.log(`Attention stop sent to ${toUserId}`);
    }
  });

  socket.on('typing', ({ roomId, userId }) => {
    socket.to(roomId).emit('user_typing', userId);
  });

  socket.on('disconnect', () => {
    // Remove from userSockets map
    for (const [userId, socketId] of userSockets.entries()) {
      if (socketId === socket.id) {
        userSockets.delete(userId);
        break;
      }
    }
    console.log('User disconnected:', socket.id);
  });
});

// REST endpoints
app.get('/api/match/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    // Get current user's interests
    const { data: user } = await supabase
      .from('profiles')
      .select('interests, age, location')
      .eq('id', userId)
      .single();

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Get potential matches (excluding self and already connected)
    const { data: candidates } = await supabase
      .from('profiles')
      .select('*')
      .neq('id', userId)
      .neq('incognito_mode', true);

    if (!candidates || candidates.length === 0) {
      return res.json([]);
    }

    // Simple scoring based on shared interests
    const scored = candidates.map(profile => {
      const sharedInterests = profile.interests?.filter(i => user.interests?.includes(i)).length || 0;
      return { ...profile, score: sharedInterests };
    });

    // Sort by score descending
    scored.sort((a, b) => b.score - a.score);
    res.json(scored.slice(0, 20));
  } catch (error) {
    console.error('Match error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/api/agora_token', (req, res) => {
  const { channelName, uid } = req.body;
  const token = RtcTokenBuilder.buildTokenWithUid(
    process.env.AGORA_APP_ID,
    process.env.AGORA_CERTIFICATE,
    channelName,
    uid || 0,
    RtcRole.PUBLISHER,
    Math.floor(Date.now() / 1000) + 3600
  );
  res.json({ token });
});

app.post('/api/upload', upload.single('file'), async (req, res) => {
  try {
    const file = req.file;
    const ext = file.originalname.split('.').pop();
    const key = `uploads/${uuidv4()}.${ext}`;
    const command = new PutObjectCommand({
      Bucket: process.env.R2_BUCKET,
      Key: key,
      Body: file.buffer,
      ContentType: file.mimetype,
    });
    await r2.send(command);
    const url = `${process.env.R2_PUBLIC_URL}/${key}`;
    res.json({ url });
  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({ error: 'Upload failed' });
  }
});

app.get('/api/connection-requests/:userId', async (req, res) => {
  const { userId } = req.params;
  const { data } = await supabase
    .from('connection_requests')
    .select('*, from_user:profiles!from_user(*)')
    .eq('to_user', userId)
    .eq('status', 'pending');
  res.json(data || []);
});

app.post('/api/connection-requests/:id/respond', async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;
  const { data } = await supabase
    .from('connection_requests')
    .update({ status, accepted_at: status === 'accepted' ? new Date().toISOString() : null })
    .eq('id', id)
    .select();
  res.json(data);
});

server.listen(process.env.PORT || 3001, () => {
  console.log(`Delulu backend running on port ${process.env.PORT || 3001}`);
});