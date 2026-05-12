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

// ── Truth or Dare Question Banks ──
const TRUTH_QUESTIONS = [
  "Tell me about your most unforgettable crush.",
  "Describe your ideal partner using only your voice.",
  "What's something you've always wanted to confess to someone?",
  "Tell the story of your most awkward date.",
  "What's one thing that instantly makes you fall for someone?",
  "Describe your perfect kiss in detail.",
  "What's your biggest relationship fear?",
  "Tell me the sweetest compliment you've ever received.",
  "What's one thing you secretly find attractive?",
  "Explain your biggest green flag in a relationship.",
  "What's your most embarrassing texting mistake?",
  "Tell me about a moment that made your heart race.",
  "What's something romantic you've never tried but want to?",
  "Describe your dream date from start to finish.",
  "What's one memory you wish you could relive?",
  "What's your biggest turn-on emotionally?",
  "Tell me about your first heartbreak.",
  "What's the cutest thing someone has done for you?",
  "What's your guilty pleasure when nobody's watching?",
  "What's one thing you wish people understood about you?",
  "What's the boldest thing you've ever done for love?",
  "Tell me your funniest relationship story.",
  "What's something you notice first about a person?",
  "If you had to flirt with me right now, what would you say?",
  "What's one thing you've never told anyone?"
];

const DARE_QUESTIONS = [
  "Send a voice note saying your best pickup line.",
  "Describe me in the flirtiest way possible.",
  "Send a dramatic 'I miss you' voice message.",
  "Tell a cheesy joke and try not to laugh.",
  "Say my name in the sweetest voice you can.",
  "Pretend we're on our first date and introduce yourself.",
  "Record yourself singing one romantic line from any song.",
  "Send a text confession like we're in a movie scene.",
  "Try to make me blush using only your voice.",
  "Send your most-used emoji and explain why.",
  "Tell me a fake love story about us in 30 seconds.",
  "Describe your perfect cuddle session.",
  "Give me a nickname and explain it dramatically.",
  "Pretend you're jealous and send a playful voice note.",
  "Roast yourself in the funniest way possible.",
  "Send a voice note with your radio-host flirting voice.",
  "Tell me your best good morning message.",
  "Describe your current mood like a romance narrator.",
  "Send a fake proposal speech.",
  "Explain why you'd survive in a dating reality show.",
  "Flirt using only three words.",
  "Pretend you're confessing your love in the rain.",
  "Say something cute without using the words cute or love.",
  "Tell me the most random thought in your head right now.",
  "End this dare with your smoothest goodbye message."
];

function getRandomQuestions(arr, count = 5) {
  return [...arr].sort(() => Math.random() - 0.5).slice(0, count);
}

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

      // Create a status message in the chat
      const msgRes = await db.query(
        'INSERT INTO messages (channel_id, sender_id, content, message_type) VALUES ($1, $2, $3, $4) RETURNING *',
        [channelId, userId, JSON.stringify({ sessionId, status: 'pending', gameId, gameName }), 'game_status']
      );

      socket.emit('game_invite_sent', { sessionId, fromName, ...data });

      io.to(peerId.toString()).emit('game_invite_received', {
        ...data,
        sessionId,
        fromName,
        fromId: userId
      });

      // Broadcast new message to both
      io.to(userId.toString()).to(peerId.toString()).emit('new_message', msgRes.rows[0]);

      // Auto-cancel if not responded within 2 minutes
      setTimeout(async () => {
        try {
          const checkRes = await db.query('SELECT status FROM game_sessions WHERE id = $1', [sessionId]);
          if (checkRes.rows.length > 0 && checkRes.rows[0].status === 'pending') {
            await db.query(
              'UPDATE game_sessions SET status = $1, updated_at = NOW() WHERE id = $2',
              ['missed', sessionId]
            );

            // Update original invitation message
            const originalMsgRes = await db.query(
              "SELECT id, content FROM messages WHERE channel_id = $1 AND message_type = 'game_status' AND (content::jsonb)->>'sessionId' = $2",
              [channelId, sessionId]
            );

            if (originalMsgRes.rows.length > 0) {
              const msgId = originalMsgRes.rows[0].id;
              let newContent;
              try {
                newContent = typeof originalMsgRes.rows[0].content === 'string' 
                  ? JSON.parse(originalMsgRes.rows[0].content) 
                  : originalMsgRes.rows[0].content;
              } catch (e) {
                newContent = {};
              }

              newContent.status = 'missed';
              const updatedMsgRes = await db.query(
                'UPDATE messages SET content = $1 WHERE id = $2 RETURNING *',
                [JSON.stringify(newContent), msgId]
              );
              io.to(userId.toString()).to(peerId.toString()).emit('message_updated', updatedMsgRes.rows[0]);
            }

            io.to(userId.toString()).to(peerId.toString()).emit('game_invite_missed', { sessionId });
          }
        } catch (err) {
          console.error('Auto-cancel error:', err);
        }
      }, 2 * 60 * 1000); // 2 minutes
    } catch (err) {
      console.error('Game invite error:', err);
    }
  });

  socket.on('game_invite_response', async (data) => {
    // data: { channelId, peerId, sessionId, accepted }
    const { channelId, peerId, sessionId, accepted } = data;
    const status = accepted ? 'accepted' : 'rejected';

    try {
      const sessionCheck = await db.query('SELECT game_id, game_name, inviter_id FROM game_sessions WHERE id = $1', [sessionId]);
      const gameId = sessionCheck.rows[0]?.game_id;
      const gameName = sessionCheck.rows[0]?.game_name;
      const inviterId = sessionCheck.rows[0]?.inviter_id;

      let initialState = null;
      if (accepted) {
        initialState = {
          phase: 'selecting_category',
          currentTurn: userId,   // Receiver (B) chooses truth/dare FIRST
          inviterId: inviterId,
          receiverId: userId,
          scores: { [inviterId]: 0, [userId]: 0 },
          category: null,
          question: null,
          suggestedQuestions: [],
          timerEndsAt: new Date(Date.now() + 30 * 1000).toISOString(),
          targetId: null,
        };
        await db.query(
          'UPDATE game_sessions SET status = $1, state = $2, updated_at = NOW() WHERE id = $3',
          [status, JSON.stringify(initialState), sessionId]
        );
        // System game message
        await db.query(
          'INSERT INTO game_messages (session_id, content, message_type) VALUES ($1, $2, $3)',
          [sessionId, 'Game started! Good luck 🎲', 'system']
        );

        // Start initial choice timeout (30s)
        setGameTimeout(sessionId, 30000, async () => {
          try {
            const checkRes = await db.query('SELECT state FROM game_sessions WHERE id = $1', [sessionId]);
            const curr = checkRes.rows[0]?.state || {};
            if (curr.phase === 'selecting_category' && curr.currentTurn === userId) {
              curr.currentTurn = inviterId; // Skip receiver if they don't choose
              curr.timerEndsAt = new Date(Date.now() + 30 * 1000).toISOString();
              await db.query('UPDATE game_sessions SET state = $1, updated_at = NOW() WHERE id = $2', [JSON.stringify(curr), sessionId]);
              const toMsg = await db.query('INSERT INTO game_messages (session_id, content, message_type) VALUES ($1, $2, $3) RETURNING *', [sessionId, 'Initial choice timeout! Turn passed.', 'system']);
              io.to(userId.toString()).to(inviterId.toString()).emit('game_state_synced', { sessionId, state: curr });
              io.to(userId.toString()).to(inviterId.toString()).emit('new_game_message', toMsg.rows[0]);
            }
          } catch (e) { console.error(e); }
        });
      } else {
        await db.query(
          'UPDATE game_sessions SET status = $1, updated_at = NOW() WHERE id = $2',
          [status, sessionId]
        );
      }

      // Update original chat invitation message status
      const originalMsgRes = await db.query(
        "SELECT id, content FROM messages WHERE channel_id = $1 AND message_type = 'game_status' AND (content::jsonb)->>'sessionId' = $2",
        [channelId, sessionId]
      );
      if (originalMsgRes.rows.length > 0) {
        const msgId = originalMsgRes.rows[0].id;
        let newContent;
        try {
          newContent = typeof originalMsgRes.rows[0].content === 'string' 
            ? JSON.parse(originalMsgRes.rows[0].content) 
            : originalMsgRes.rows[0].content;
        } catch (e) {
          newContent = {};
        }
        
        newContent.status = status;
        const updatedMsgRes = await db.query(
          'UPDATE messages SET content = $1 WHERE id = $2 RETURNING *',
          [JSON.stringify(newContent), msgId]
        );
        io.to(userId.toString()).to(peerId.toString()).emit('message_updated', updatedMsgRes.rows[0]);
      }

      // Chat status message for the response
      const msgRes = await db.query(
        'INSERT INTO messages (channel_id, sender_id, content, message_type) VALUES ($1, $2, $3, $4) RETURNING *',
        [channelId, userId, JSON.stringify({ sessionId, status, gameId, gameName }), 'game_status']
      );

      io.to(peerId.toString()).to(userId.toString()).emit('game_invite_response_received', { ...data, status, fromId: userId });
      io.to(userId.toString()).to(peerId.toString()).emit('new_message', msgRes.rows[0]);

      // Sync initial game state to both players when accepted
      if (accepted && initialState) {
        io.to(userId.toString()).to(peerId.toString()).emit('game_state_synced', { sessionId, state: initialState });
      }
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

  // --- Authoritative Truth or Dare Game Engine ---
  const activeGameTimers = new Map();

  const setGameTimeout = (sessionId, delay, callback) => {
    if (activeGameTimers.has(sessionId)) clearTimeout(activeGameTimers.get(sessionId));
    const timeout = setTimeout(callback, delay);
    activeGameTimers.set(sessionId, timeout);
  };

  socket.on('game_select_choice', async ({ sessionId, choice, peerId }) => {
    console.log(`[Game] Choice received: ${choice} for session ${sessionId}`);
    try {
      const res = await db.query('SELECT state FROM game_sessions WHERE id = $1', [sessionId]);
      if (res.rows.length === 0) return;

      const state = res.rows[0].state || {};
      if (state.currentTurn !== userId || state.phase !== 'selecting_category') return;

      const qRes = await db.query(
        `SELECT content FROM ${choice === 'truth' ? 'truth_questions' : 'dare_questions'} ORDER BY RANDOM() LIMIT 3`
      );
      const suggestions = qRes.rows.map(r => r.content);

      state.phase = 'selecting_question';
      state.category = choice;
      state.suggestedQuestions = suggestions;
      state.currentTurn = peerId;
      state.targetId = userId;
      state.timerEndsAt = new Date(Date.now() + 120 * 1000).toISOString(); // 120s for question

      await db.query('UPDATE game_sessions SET state = $1, updated_at = NOW() WHERE id = $2', [JSON.stringify(state), sessionId]);

      const nameRes = await db.query('SELECT display_name FROM profiles WHERE user_id = $1', [userId]);
      const displayName = nameRes.rows[0]?.display_name || 'Someone';
      const gmRes = await db.query(
        'INSERT INTO game_messages (session_id, content, message_type) VALUES ($1, $2, $3) RETURNING *',
        [sessionId, `${displayName} chose ${choice.toUpperCase()}! Waiting for question...`, 'system']
      );

      io.to(userId.toString()).to(peerId.toString()).emit('game_state_synced', { sessionId, state });
      io.to(userId.toString()).to(peerId.toString()).emit('new_game_message', gmRes.rows[0]);

      // Set timeout for selecting question (120s)
      setGameTimeout(sessionId, 120000, async () => {
        try {
          const checkRes = await db.query('SELECT state FROM game_sessions WHERE id = $1', [sessionId]);
          const curr = checkRes.rows[0]?.state || {};
          if (curr.phase === 'selecting_question') {
            curr.phase = 'selecting_category';
            curr.currentTurn = userId; // Back to the original chooser
            curr.timerEndsAt = new Date(Date.now() + 30 * 1000).toISOString();
            await db.query('UPDATE game_sessions SET state = $1, updated_at = NOW() WHERE id = $2', [JSON.stringify(curr), sessionId]);
            const toMsg = await db.query('INSERT INTO game_messages (session_id, content, message_type) VALUES ($1, $2, $3) RETURNING *', [sessionId, 'Question timeout! Turn skipped.', 'system']);
            io.to(userId.toString()).to(peerId.toString()).emit('game_state_synced', { sessionId, state: curr });
            io.to(userId.toString()).to(peerId.toString()).emit('new_game_message', toMsg.rows[0]);
          }
        } catch (e) { console.error(e); }
      });
    } catch (err) { console.error('[Game] Select choice error:', err); }
  });

  socket.on('game_send_question', async ({ sessionId, question, peerId }) => {
    try {
      const res = await db.query('SELECT state FROM game_sessions WHERE id = $1', [sessionId]);
      if (res.rows.length === 0) return;
      const state = res.rows[0].state || {};
      if (state.currentTurn !== userId || state.phase !== 'selecting_question') return;

      state.phase = 'answering';
      state.question = question;
      state.currentTurn = peerId;
      state.timerEndsAt = new Date(Date.now() + 90 * 1000).toISOString(); // 90s for answer

      await db.query('UPDATE game_sessions SET state = $1, updated_at = NOW() WHERE id = $2', [JSON.stringify(state), sessionId]);
      const gmRes = await db.query('INSERT INTO game_messages (session_id, sender_id, content, message_type) VALUES ($1, $2, $3, $4) RETURNING *', [sessionId, userId, question, 'question']);
      io.to(userId.toString()).to(peerId.toString()).emit('game_state_synced', { sessionId, state });
      io.to(userId.toString()).to(peerId.toString()).emit('new_game_message', gmRes.rows[0]);

      // Set timeout for answering (90s)
      setGameTimeout(sessionId, 90000, async () => {
        try {
          const checkRes = await db.query('SELECT state FROM game_sessions WHERE id = $1', [sessionId]);
          const curr = checkRes.rows[0]?.state || {};
          if (curr.phase === 'answering') {
            curr.phase = 'selecting_category';
            curr.currentTurn = userId; // Back to the one who asked
            curr.timerEndsAt = new Date(Date.now() + 30 * 1000).toISOString();
            await db.query('UPDATE game_sessions SET state = $1, updated_at = NOW() WHERE id = $2', [JSON.stringify(curr), sessionId]);
            const toMsg = await db.query('INSERT INTO game_messages (session_id, content, message_type) VALUES ($1, $2, $3) RETURNING *', [sessionId, 'Answer timeout! Next turn.', 'system']);
            io.to(userId.toString()).to(peerId.toString()).emit('game_state_synced', { sessionId, state: curr });
            io.to(userId.toString()).to(peerId.toString()).emit('new_game_message', toMsg.rows[0]);
          }
        } catch (e) { console.error(e); }
      });
    } catch (err) { console.error(err); }
  });

  socket.on('game_submit_answer', async ({ sessionId, answer, peerId, type }) => {
    try {
      if (activeGameTimers.has(sessionId)) {
        clearTimeout(activeGameTimers.get(sessionId));
        activeGameTimers.delete(sessionId);
      }
      const res = await db.query('SELECT state FROM game_sessions WHERE id = $1', [sessionId]);
      if (res.rows.length === 0) return;
      const state = res.rows[0].state || {};
      if (state.currentTurn !== userId || state.phase !== 'answering') return;

      state.scores = state.scores || {};
      state.scores[userId] = (state.scores[userId] || 0) + 1;
      state.phase = 'selecting_category';
      state.category = null;
      state.question = null;
      state.suggestedQuestions = [];
      state.timerEndsAt = new Date(Date.now() + 30 * 1000).toISOString(); // 30s for next choice
      state.currentTurn = peerId;

      await db.query('UPDATE game_sessions SET state = $1, updated_at = NOW() WHERE id = $2', [JSON.stringify(state), sessionId]);
      const gmRes = await db.query('INSERT INTO game_messages (session_id, sender_id, content, message_type) VALUES ($1, $2, $3, $4) RETURNING *', [sessionId, userId, answer, type || 'text']);
      io.to(userId.toString()).to(peerId.toString()).emit('game_state_synced', { sessionId, state });
      io.to(userId.toString()).to(peerId.toString()).emit('new_game_message', gmRes.rows[0]);
      io.to(userId.toString()).to(peerId.toString()).emit('game_points_synced', { sessionId, scores: state.scores });

      // Set timeout for next category selection (30s)
      setGameTimeout(sessionId, 30000, async () => {
        try {
          const checkRes = await db.query('SELECT state FROM game_sessions WHERE id = $1', [sessionId]);
          const curr = checkRes.rows[0]?.state || {};
          if (curr.phase === 'selecting_category' && curr.currentTurn === peerId) {
            curr.currentTurn = userId; // Skip peer if they don't choose
            curr.timerEndsAt = new Date(Date.now() + 30 * 1000).toISOString();
            await db.query('UPDATE game_sessions SET state = $1, updated_at = NOW() WHERE id = $2', [JSON.stringify(curr), sessionId]);
            const toMsg = await db.query('INSERT INTO game_messages (session_id, content, message_type) VALUES ($1, $2, $3) RETURNING *', [sessionId, 'Selection timeout! Turn passed.', 'system']);
            io.to(userId.toString()).to(peerId.toString()).emit('game_state_synced', { sessionId, state: curr });
            io.to(userId.toString()).to(peerId.toString()).emit('new_game_message', toMsg.rows[0]);
          }
        } catch (e) { console.error(e); }
      });
    } catch (err) { console.error(err); }
  });

  socket.on('game_state_update', async (data) => {
    // data: { sessionId, state, peerId }
    const { sessionId, state, peerId } = data;
    try {
      await db.query(
        'UPDATE game_sessions SET state = $1, updated_at = NOW() WHERE id = $2',
        [JSON.stringify(state), sessionId]
      );
      io.to(peerId.toString()).emit('game_state_synced', { sessionId, state });
    } catch (err) {
      console.error('Game state update error:', err);
    }
  });

  socket.on('game_point_update', async (data) => {
    // data: { sessionId, userId, points, peerId }
    const { sessionId, userId: targetUserId, points, peerId } = data;
    try {
      const currentPointsRes = await db.query('SELECT match_points FROM profiles WHERE user_id = $1', [targetUserId]);
      let currentPoints = currentPointsRes.rows[0]?.match_points || 0;
      let newPoints = currentPoints + points;
      if (newPoints < 0) newPoints = 0;

      await db.query(
        'UPDATE profiles SET match_points = $1 WHERE user_id = $2',
        [newPoints, targetUserId]
      );

      io.to(targetUserId.toString()).to(peerId.toString()).emit('game_points_synced', { 
        sessionId, 
        userId: targetUserId, 
        points: newPoints,
        delta: points
      });
    } catch (err) {
      console.error('Game point update error:', err);
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

  socket.on('game_end', async (data) => {
    // data: { sessionId, peerId, channelId }
    const { sessionId, peerId, channelId } = data;
    try {
      await db.query(
        'UPDATE game_sessions SET status = $1, updated_at = NOW() WHERE id = $2',
        ['completed', sessionId]
      );

      // Update original chat invitation message status to completed
      const originalMsgRes = await db.query(
        "SELECT id, content FROM messages WHERE channel_id = $1 AND message_type = 'game_status' AND (content::jsonb)->>'sessionId' = $2",
        [channelId, sessionId]
      );
      if (originalMsgRes.rows.length > 0) {
        const msgId = originalMsgRes.rows[0].id;
        let newContent;
        try {
          newContent = typeof originalMsgRes.rows[0].content === 'string' 
            ? JSON.parse(originalMsgRes.rows[0].content) 
            : originalMsgRes.rows[0].content;
        } catch (e) { newContent = {}; }
        newContent.status = 'completed';
        await db.query('UPDATE messages SET content = $1 WHERE id = $2', [JSON.stringify(newContent), msgId]);
      }

      // Get display name for the transient notification (toast)
      const nameRes = await db.query('SELECT display_name FROM profiles WHERE user_id = $1', [userId]);
      const displayName = nameRes.rows[0]?.display_name || 'Someone';

      // We no longer insert a 'text' message into the DB to keep chat clean.
      // We only emit the event to notify the peer.
      io.to(peerId.toString()).emit('game_ended_by_peer', { 
        sessionId,
        userName: displayName
      });
      
      // Notify both to refresh UI if they have chat open (card status changed)
      io.to(userId.toString()).to(peerId.toString()).emit('message_updated', { 
        id: originalMsgRes.rows[0]?.id, 
        content: { sessionId, status: 'completed' } // Simplified for update listener
      });

    } catch (err) {
      console.error('Game end error:', err);
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
