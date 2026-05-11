require('dotenv').config();
const db = require('./db');

async function run() {
  console.log('Running game_sessions status constraint migration...');
  
  try {
    // Drop the old constraint
    await db.query(`
      ALTER TABLE game_sessions DROP CONSTRAINT IF EXISTS game_sessions_status_check;
    `);
    console.log('  ✅ Dropped old status constraint');

    // Add the new constraint with 'completed' included
    await db.query(`
      ALTER TABLE game_sessions ADD CONSTRAINT game_sessions_status_check
        CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled', 'missed', 'completed'));
    `);
    console.log('  ✅ Added new status constraint (with "completed")');

    // Verify it's correct
    const check = await db.query(`
      SELECT check_clause FROM information_schema.check_constraints
      WHERE constraint_name = 'game_sessions_status_check'
    `);
    console.log('  Constraint is now:', check.rows[0]?.check_clause);

    // Test that 'completed' now works
    const gamesRes = await db.query('SELECT id FROM games LIMIT 1');
    const chRes = await db.query('SELECT id, user1_id, user2_id FROM channels ORDER BY id DESC LIMIT 1');
    const ch = chRes.rows[0];
    const gameId = gamesRes.rows[0].id;

    const ins = await db.query(`
      INSERT INTO game_sessions (channel_id, inviter_id, receiver_id, game_id, game_name, status)
      VALUES ($1, $2, $3, $4, 'Test', 'completed') RETURNING id
    `, [ch.id, ch.user1_id, ch.user2_id, gameId]);
    console.log('  ✅ Test insert with "completed" succeeded:', ins.rows[0].id);
    await db.query('DELETE FROM game_sessions WHERE id = $1', [ins.rows[0].id]);
    console.log('  ✅ Cleanup done');

    console.log('\nMigration complete!');
  } catch (e) {
    console.error('Migration FAILED:', e.message);
  }

  process.exit(0);
}

run().catch(e => { console.error(e); process.exit(1); });
