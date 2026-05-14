const jwt = require('jsonwebtoken');
const db = require('../db');

async function authMiddleware(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No token provided' });
  }

  const token = header.split(' ')[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.userId = decoded.userId;

    // Check if user is blocked
    const userRes = await db.query('SELECT is_blocked FROM users WHERE id = $1', [req.userId]);
    if (userRes.rows.length === 0) {
      return res.status(401).json({ error: 'User not found' });
    }

    if (userRes.rows[0].is_blocked) {
      return res.status(403).json({ error: 'Account blocked', code: 'USER_BLOCKED' });
    }

    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

module.exports = authMiddleware;