const fs = require('fs');
const path = 'backend/routes/onboarding.js';
let content = fs.readFileSync(path, 'utf8');
content = content.replace('COALESCE($2, 0)', 'COALESCE($2, 18)');
fs.writeFileSync(path, content);
console.log('Done');
