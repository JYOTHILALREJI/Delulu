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
    } catch (e) {}

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
          `);
      console.log('  ✓ updated users table columns');
    } catch (e) {}

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
        description TEXT,
        min_messages_required INTEGER DEFAULT 200,
        daily_free_plays INTEGER DEFAULT 3,
        unlimited_with_subscription BOOLEAN DEFAULT TRUE,
        is_premium BOOLEAN DEFAULT FALSE,
        phases JSONB DEFAULT '[]'::jsonb,
        active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    console.log('  ✓ games');

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
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    console.log('  ✓ game_sessions');
    
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

    // Initial games data
    await client.query(`
      INSERT INTO games (id, name, icon, description, min_messages_required, daily_free_plays, unlimited_with_subscription, is_premium, phases)
      VALUES 
      (
        'truth_or_dare', 
        'Truth or Dare', 
        '🎲', 
        'Spicy questions and dares for couples', 
        200, 
        3, 
        TRUE, 
        FALSE,
        '[
          {"type": "choose_category", "options": ["truth", "dare"]},
          {"type": "ask_question", "preStoredQuestions": ["What is your biggest secret?", "Have you ever cheated on a test?", "Dare: Send a voice note of you singing"]},
          {"type": "answer_question"}
        ]'::jsonb
      ),
      (
        'would_you_rather', 
        'Would You Rather', 
        '🤔', 
        'Classic dilemma game to know them better', 
        500, 
        5, 
        TRUE, 
        FALSE,
        '[
          {"type": "ask_question", "preStoredQuestions": ["Would you rather travel to the future or the past?", "Would you rather always be 10 minutes late or 20 minutes early?"]},
          {"type": "answer_question"}
        ]'::jsonb
      ),
      (
        'rizz_master', 
        'Rizz Master', 
        '🔥', 
        'Test your charm and see who has more rizz', 
        1000, 
        2, 
        TRUE, 
        TRUE,
        '[]'::jsonb
      )
      ON CONFLICT (id) DO UPDATE SET 
        name = EXCLUDED.name,
        icon = EXCLUDED.icon,
        description = EXCLUDED.description,
        min_messages_required = EXCLUDED.min_messages_required,
        is_premium = EXCLUDED.is_premium;
    `);

    // Add boosting columns to profiles
    try {
      await client.query(`
        ALTER TABLE profiles ADD COLUMN IF NOT EXISTS streak_count INTEGER DEFAULT 0;
        ALTER TABLE profiles ADD COLUMN IF NOT EXISTS popularity_score DOUBLE PRECISION DEFAULT 0;
      `);
      console.log('  ✓ added boosting columns to profiles');
    } catch (e) {}

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