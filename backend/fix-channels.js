require('dotenv').config();
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function fixChannels() {
  const client = await pool.connect();
  try {
    console.log('Fixing missing channels for accepted requests...');
    
    const requests = await client.query(`
      SELECT sender_id, receiver_id 
      FROM connection_requests 
      WHERE status = 'accepted'
    `);
    
    console.log(`Found ${requests.rows.length} accepted requests.`);
    
    for (const req of requests.rows) {
      const [u1, u2] = [req.sender_id, req.receiver_id].sort();
      await client.query(`
        INSERT INTO channels (user1_id, user2_id)
        VALUES ($1, $2)
        ON CONFLICT (user1_id, user2_id) DO NOTHING
      `, [u1, u2]);
    }
    
    console.log('Finished fixing channels.');
  } catch (err) {
    console.error('Error fixing channels:', err);
  } finally {
    client.release();
    pool.end();
  }
}

fixChannels();
