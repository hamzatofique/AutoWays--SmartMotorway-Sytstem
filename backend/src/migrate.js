require('dotenv').config();
const fs = require('fs');
const path = require('path');
const pool = require('./config/db');

const file = process.argv[2] || 'sql/schema.sql';

(async () => {
  const sql = fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
  await pool.query(sql);
  console.log('Ran', file);
  const r = await pool.query(
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'");
  console.log('Tables in public:', r.rows[0].count);
  await pool.end();
})().catch(e => { console.error('ERROR:', e.message); process.exit(1); });