require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function initDb() {
  const client = await pool.connect();
  try {
    console.log('Creating tables...\n');

    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        display_name VARCHAR(100) DEFAULT '',
        is_onboarded BOOLEAN DEFAULT FALSE,
        terms_accepted_at TIMESTAMPTZ,
        privacy_accepted_at TIMESTAMPTZ,
        is_premium_user BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    console.log('  ✓ users');

    await client.query(`
      CREATE TABLE IF NOT EXISTS profiles (
        user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        display_name VARCHAR(100) NOT NULL,
        age INTEGER NOT NULL CHECK (age >= 13 AND age <= 120),
        gender VARCHAR(50) NOT NULL,
        interested_in VARCHAR(50) NOT NULL,
        bio VARCHAR(200) DEFAULT '',
        interests JSONB DEFAULT '[]'::jsonb,
        photos JSONB DEFAULT '[]'::jsonb,
        latitude DOUBLE PRECISION,
        longitude DOUBLE PRECISION,
        live_location_enabled BOOLEAN DEFAULT FALSE,
        online_status_enabled BOOLEAN DEFAULT TRUE,
        typing_indicator_enabled BOOLEAN DEFAULT TRUE,
        last_seen_enabled BOOLEAN DEFAULT TRUE,
        read_receipt_enabled BOOLEAN DEFAULT TRUE,
        location_name VARCHAR(255) DEFAULT '',
        is_premium BOOLEAN DEFAULT FALSE,
        last_attention_seeker_at TIMESTAMPTZ,
        last_seen_at TIMESTAMPTZ,
        likes_count INTEGER DEFAULT 0,
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    console.log('  ✓ profiles');

    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
    `);
    console.log('  ✓ indexes');

    await client.query(`
      CREATE TABLE IF NOT EXISTS likes (
        id SERIAL PRIMARY KEY,
        liker_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        liked_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE(liker_user_id, liked_user_id)
      );
    `);
    console.log('  ✓ likes');

    await client.query(`
      CREATE TABLE IF NOT EXISTS connection_requests (
        id SERIAL PRIMARY KEY,
        sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
        created_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE(sender_id, receiver_id)
      );
    `);
    console.log('  ✓ connection_requests');

    // Channels table (one per accepted connection)
    await client.query(`
      CREATE TABLE IF NOT EXISTS channels (
        id SERIAL PRIMARY KEY,
        user1_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        user2_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE(user1_id, user2_id)
      );
    `);
    console.log('  ✓ channels');

    // Messages table
    await client.query(`
      CREATE TABLE IF NOT EXISTS messages (
        id SERIAL PRIMARY KEY,
        channel_id INTEGER NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
        sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        content TEXT NOT NULL,
        message_type VARCHAR(20) DEFAULT 'text',
        duration INTEGER,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        read_at TIMESTAMPTZ
      );
    `);
    console.log('  ✓ messages');

    try {
      await client.query(`
        ALTER TABLE messages ADD COLUMN IF NOT EXISTS message_type VARCHAR(20) DEFAULT 'text';
        ALTER TABLE messages ADD COLUMN IF NOT EXISTS duration INTEGER;
      `);
    } catch (e) { }

    // Add missing columns if upgrading existing db
    const profileColumns = [
      { name: 'online_status_enabled', type: 'BOOLEAN DEFAULT TRUE' },
      { name: 'typing_indicator_enabled', type: 'BOOLEAN DEFAULT TRUE' },
      { name: 'last_seen_enabled', type: 'BOOLEAN DEFAULT TRUE' },
      { name: 'read_receipt_enabled', type: 'BOOLEAN DEFAULT TRUE' },
      { name: 'location_name', type: 'VARCHAR(255) DEFAULT \'\'' },
      { name: 'is_premium', type: 'BOOLEAN DEFAULT FALSE' },
      { name: 'last_attention_seeker_at', type: 'TIMESTAMPTZ' },
      { name: 'last_seen_at', type: 'TIMESTAMPTZ' },
      { name: 'likes_count', type: 'INTEGER DEFAULT 0' },
      { name: 'e2e_encryption_enabled', type: 'BOOLEAN DEFAULT FALSE' },
      { name: 'hide_location_enabled', type: 'BOOLEAN DEFAULT FALSE' },
      { name: 'premium_since', type: 'TIMESTAMPTZ' },
      { name: 'match_points', type: 'INTEGER DEFAULT 0' }
    ];

    for (const col of profileColumns) {
      try {
        await client.query(`ALTER TABLE profiles ADD COLUMN IF NOT EXISTS ${col.name} ${col.type};`);
        console.log(`  ✓ added ${col.name} to profiles (if missing)`);
      } catch (e) {
        console.error(`  ✕ error adding ${col.name}:`, e.message);
      }
    }

    // User columns for attention seeker
    const userColumns = [
      { name: 'attention_seeker_last_used', type: 'TIMESTAMPTZ' },
      { name: 'attention_seeker_free_used', type: 'BOOLEAN DEFAULT FALSE' }
    ];

    for (const col of userColumns) {
      try {
        await client.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS ${col.name} ${col.type};`);
        console.log(`  ✓ added ${col.name} to users (if missing)`);
      } catch (e) {
        console.error(`  ✕ error adding ${col.name}:`, e.message);
      }
    }

    // Message reactions table
    await client.query(`
      CREATE TABLE IF NOT EXISTS message_reactions (
        id SERIAL PRIMARY KEY,
        message_id INTEGER REFERENCES messages(id) ON DELETE CASCADE,
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        reaction VARCHAR(10) NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE(message_id, user_id)
      );
    `);
    console.log('  ✓ message_reactions');

    // Add missing columns to games
    const gameColumns = [
      { name: 'is_premium', type: 'BOOLEAN DEFAULT FALSE' }
    ];

    for (const col of gameColumns) {
      try {
        await client.query(`ALTER TABLE games ADD COLUMN IF NOT EXISTS ${col.name} ${col.type};`);
        console.log(`  ✓ added ${col.name} to games (if missing)`);
      } catch (e) {
        console.error(`  ✕ error adding ${col.name} to games:`, e.message);
      }
    }

    try {
      await client.query(`
            ALTER TABLE users ADD COLUMN IF NOT EXISTS display_name VARCHAR(100) DEFAULT '';
            ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
            ALTER TABLE users ADD COLUMN IF NOT EXISTS onboarding_step INTEGER DEFAULT 0;
            ALTER TABLE users ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMPTZ;
            ALTER TABLE users ADD COLUMN IF NOT EXISTS privacy_accepted_at TIMESTAMPTZ;
            ALTER TABLE users ADD COLUMN IF NOT EXISTS is_premium_user BOOLEAN DEFAULT FALSE;
          `);
      console.log('  ✓ updated users table columns');
    } catch (e) { }

    // Blocks table
    await client.query(`
      CREATE TABLE IF NOT EXISTS blocks (
        id SERIAL PRIMARY KEY,
        blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE(blocker_id, blocked_id)
      );
    `);
    console.log('  ✓ blocks');

    // Reports table
    await client.query(`
      CREATE TABLE IF NOT EXISTS reports (
        id SERIAL PRIMARY KEY,
        reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        reported_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        reason TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    console.log('  ✓ reports');

    // Games table
    await client.query(`
      CREATE TABLE IF NOT EXISTS games (
        id VARCHAR(50) PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        icon VARCHAR(50),
        image_url TEXT,
        description TEXT,
        category VARCHAR(50) DEFAULT 'fun',
        min_messages_required INTEGER DEFAULT 20,
        daily_free_plays INTEGER DEFAULT 3,
        unlimited_with_subscription BOOLEAN DEFAULT TRUE,
        is_premium BOOLEAN DEFAULT FALSE,
        phases JSONB DEFAULT '[]'::jsonb,
        active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    // Add new columns if they don't exist (migration safety)
    await client.query(`ALTER TABLE games ADD COLUMN IF NOT EXISTS image_url TEXT;`);
    await client.query(`ALTER TABLE games ADD COLUMN IF NOT EXISTS category VARCHAR(50) DEFAULT 'fun';`);
    console.log('  ✓ games');

    // Truth questions table
    await client.query(`
      CREATE TABLE IF NOT EXISTS truth_questions (
        id SERIAL PRIMARY KEY,
        content TEXT NOT NULL,
        difficulty VARCHAR(20) DEFAULT 'medium',
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    console.log('  ✓ truth_questions');

    // Dare questions table
    await client.query(`
      CREATE TABLE IF NOT EXISTS dare_questions (
        id SERIAL PRIMARY KEY,
        content TEXT NOT NULL,
        difficulty VARCHAR(20) DEFAULT 'medium',
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    console.log('  ✓ dare_questions');

    // Seed Truth Questions
    await client.query(`
      INSERT INTO truth_questions (content) VALUES 
      ('Tell me about your most unforgettable crush.'),
      ('Describe your ideal partner using only your voice.'),
      ('What’s something you’ve always wanted to confess to someone?'),
      ('Tell the story of your most awkward date.'),
      ('What’s one thing that instantly makes you fall for someone?'),
      ('Describe your perfect kiss in detail.'),
      ('What’s your biggest relationship fear?'),
      ('Tell me the sweetest compliment you’ve ever received.'),
      ('What’s one thing you secretly find attractive?'),
      ('Explain your biggest green flag in a relationship.'),
      ('What’s your most embarrassing texting mistake?'),
      ('Tell me about a moment that made your heart race.'),
      ('What’s something romantic you’ve never tried but want to?'),
      ('Describe your dream date from start to finish.'),
      ('What’s one memory you wish you could relive?'),
      ('What’s your biggest turn-on emotionally?'),
      ('Tell me about your first heartbreak.'),
      ('What’s the cutest thing someone has done for you?'),
      ('What’s your guilty pleasure when nobody’s watching?'),
      ('Describe your “perfect night together.”')
      ON CONFLICT DO NOTHING;
    `);

    // Seed Dare Questions
    await client.query(`
      INSERT INTO dare_questions (content) VALUES 
      ('Send a voice note saying your best pickup line.'),
      ('Describe me in the flirtiest way possible.'),
      ('Send a dramatic “I miss you” voice message.'),
      ('Tell a cheesy joke and try not to laugh.'),
      ('Say my name in the sweetest voice you can.'),
      ('Pretend we’re on our first date and introduce yourself.'),
      ('Record yourself singing one romantic line from any song.'),
      ('Send a text confession like we’re in a movie scene.'),
      ('Try to make me blush using only your voice.'),
      ('Send your most-used emoji and explain why.'),
      ('Tell me a fake love story about us in 30 seconds.'),
      ('Describe your perfect cuddle session.'),
      ('Give me a nickname and explain it dramatically.'),
      ('Pretend you’re jealous and send a playful voice note.'),
      ('Roast yourself in the funniest way possible.'),
      ('Send a voice note with your “radio host” flirting voice.'),
      ('Tell me your best “good morning” message.'),
      ('Describe your current mood like a romance narrator.'),
      ('Send a fake proposal speech.'),
      ('Explain why you’d survive in a dating reality show.')
      ON CONFLICT DO NOTHING;
    `);

    // Streaks table
    await client.query(`
      CREATE TABLE IF NOT EXISTS streaks (
        id SERIAL PRIMARY KEY,
        user1_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        user2_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        count INTEGER DEFAULT 0,
        last_message_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE(user1_id, user2_id)
      );
    `);
    console.log('  ✓ streaks');

    // Game Sessions table
    await client.query(`
      CREATE TABLE IF NOT EXISTS game_sessions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        channel_id INTEGER NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
        inviter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        game_id VARCHAR(50) NOT NULL REFERENCES games(id),
        game_name VARCHAR(100) NOT NULL,
        status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled', 'missed', 'completed')),
        duration INTEGER DEFAULT 0,
        state JSONB DEFAULT '{}'::jsonb,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    console.log('  ✓ game_sessions');

    // Migration: ensure state column exists in game_sessions
    try {
      await client.query(`
        ALTER TABLE game_sessions ADD COLUMN IF NOT EXISTS state JSONB DEFAULT '{}'::jsonb;
        ALTER TABLE game_sessions ADD COLUMN IF NOT EXISTS duration INTEGER DEFAULT 0;
        ALTER TABLE game_sessions ADD COLUMN IF NOT EXISTS game_name VARCHAR(100);
      `);
    } catch (e) {
      console.log('  Note: game_sessions migration partially applied or skipped.');
    }

    // Game Messages table (separate from chat messages)
    await client.query(`
      CREATE TABLE IF NOT EXISTS game_messages (
        id SERIAL PRIMARY KEY,
        session_id UUID NOT NULL REFERENCES game_sessions(id) ON DELETE CASCADE,
        sender_id UUID REFERENCES users(id) ON DELETE SET NULL,
        content TEXT NOT NULL,
        message_type VARCHAR(30) DEFAULT 'text',
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_game_messages_session ON game_messages(session_id);`);
    console.log('  ✓ game_messages');

    // Game Plays table — tracks daily free play usage per user per game
    await client.query(`
      CREATE TABLE IF NOT EXISTS game_plays (
        id SERIAL PRIMARY KEY,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        game_id VARCHAR(50) NOT NULL REFERENCES games(id) ON DELETE CASCADE,
        channel_id INTEGER REFERENCES channels(id) ON DELETE SET NULL,
        played_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_game_plays_user_game ON game_plays(user_id, game_id);`);
    console.log('  ✓ game_plays');

    // Subscription Plans table
    await client.query(`
      CREATE TABLE IF NOT EXISTS subscription_plans (
        id VARCHAR(50) PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        price_text VARCHAR(20) NOT NULL,
        period_text VARCHAR(50) NOT NULL,
        tag VARCHAR(50),
        savings_text VARCHAR(50),
        sort_order INTEGER DEFAULT 0,
        active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    console.log('  ✓ subscription_plans');

    // Subscriptions table
    await client.query(`
      CREATE TABLE IF NOT EXISTS subscriptions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        plan_id VARCHAR(50) NOT NULL REFERENCES subscription_plans(id),
        status VARCHAR(20) DEFAULT 'active',
        store VARCHAR(20),
        transaction_id TEXT,
        purchase_token TEXT,
        expiry_date TIMESTAMPTZ,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE(user_id, transaction_id)
      );
    `);
    console.log('  ✓ subscriptions');

    // Seed Subscription Plans
    await client.query(`
      INSERT INTO subscription_plans (id, name, price_text, period_text, tag, savings_text, sort_order)
      VALUES 
      ('monthly', 'Monthly', '$9.99', '/ month', NULL, NULL, 0),
      ('6_months', '6 Months', '$49.99', '/ 6 months', 'MOST POPULAR', '15% OFF', 1),
      ('yearly', 'Yearly', '$79.99', '/ year', 'BEST VALUE', '33% OFF', 2)
      ON CONFLICT (id) DO NOTHING;
    `);

    // Initial games data — all fields updated on conflict so admin edits persist after restart
    await client.query(`
      INSERT INTO games (id, name, icon, image_url, description, category, min_messages_required, daily_free_plays, unlimited_with_subscription, is_premium, phases, active)
      VALUES 
      (
        'truth_or_dare',
        'Truth or Dare',
        '🎲',
        'assets/game_icons/t_or_d_logo.png',
        'Spicy questions and dares for couples',
        'fun',
        20,
        10,
        TRUE,
        FALSE,
        '[
          {"type": "choose_category", "options": ["truth", "dare"]},
          {"type": "ask_question", "preStoredQuestions": ["What is your biggest secret?", "Have you ever cheated on a test?", "Dare: Send a voice note of you singing"]},
          {"type": "answer_question"}
        ]'::jsonb,
        TRUE
      ),
      (
        'would_you_rather',
        'Would You Rather',
        '🤔',
        NULL,
        'Classic dilemma game to know them better',
        'fun',
        100,
        5,
        TRUE,
        FALSE,
        '[
          {"type": "ask_question", "preStoredQuestions": ["Would you rather travel to the future or the past?", "Would you rather always be 10 minutes late or 20 minutes early?"]},
          {"type": "answer_question"}
        ]'::jsonb,
        TRUE
      ),
      (
        'rizz_master',
        'Rizz Master',
        '🔥',
        NULL,
        'Test your charm and see who has more rizz',
        'premium',
        500,
        2,
        TRUE,
        TRUE,
        '[]'::jsonb,
        TRUE
      )
      ON CONFLICT (id) DO UPDATE SET
        name                    = EXCLUDED.name,
        icon                    = EXCLUDED.icon,
        image_url               = EXCLUDED.image_url,
        description             = EXCLUDED.description,
        category                = EXCLUDED.category,
        min_messages_required   = EXCLUDED.min_messages_required,
        daily_free_plays        = EXCLUDED.daily_free_plays,
        unlimited_with_subscription = EXCLUDED.unlimited_with_subscription,
        is_premium              = EXCLUDED.is_premium,
        phases                  = EXCLUDED.phases,
        active                  = EXCLUDED.active;
    `);

    // Add boosting columns to profiles
    try {
      await client.query(`
        ALTER TABLE profiles ADD COLUMN IF NOT EXISTS streak_count INTEGER DEFAULT 0;
        ALTER TABLE profiles ADD COLUMN IF NOT EXISTS popularity_score DOUBLE PRECISION DEFAULT 0;
      `);
      console.log('  ✓ added boosting columns to profiles');
    } catch (e) { }

    console.log('\nDatabase initialized successfully.');
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }

}

initDb();