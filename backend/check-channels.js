const db = require('./db');
const userId = process.argv[2];

async function check() {
  try {
    const res = await db.query(
      `SELECT c.id, c.user1_id, c.user2_id, u.display_name
       FROM channels c
       JOIN users u ON (CASE WHEN c.user1_id = $1 THEN c.user2_id ELSE c.user1_id END) = u.id
       WHERE (c.user1_id = $1 OR c.user2_id = $1)`,
      [userId]
    );
    console.log('Channels found:', res.rows);
  } catch (err) {
    console.error('Error:', err);
  } finally {
    process.exit();
  }
}

if (!userId) {
  console.log('Usage: node check-channels.js <user_id>');
  process.exit();
}
check();
