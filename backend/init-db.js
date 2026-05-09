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
      { name: 'likes_count', type: 'INTEGER DEFAULT 0' }
    ];

    for (const col of profileColumns) {
      try {
        await client.query(`ALTER TABLE profiles ADD COLUMN IF NOT EXISTS ${col.name} ${col.type};`);
        console.log(`  ✓ added ${col.name} to profiles (if missing)`);
      } catch (e) {
        console.error(`  ✕ error adding ${col.name}:`, e.message);
      }
    }

    try {
      await client.query(`
            ALTER TABLE users ADD COLUMN IF NOT EXISTS display_name VARCHAR(100) DEFAULT '';
            ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
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