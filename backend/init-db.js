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
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    console.log('  ✓ profiles');

    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
    `);
    console.log('  ✓ indexes');

    // Add display_name column if upgrading existing db
    try {
      await client.query(`
        ALTER TABLE users ADD COLUMN IF NOT EXISTS display_name VARCHAR(100) DEFAULT '';
      `);
      console.log('  ✓ added display_name to users (if missing)');
    } catch (e) {
      // Column already exists, ignore
    }

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