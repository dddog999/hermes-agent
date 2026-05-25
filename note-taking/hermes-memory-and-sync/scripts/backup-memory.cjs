// Backup Hermes memory to Nutstore sync directory
// Naming: wooking-win_MEMORY_YYYYMMDD.md (distinct from WSL's "wooking_" prefix)

const fs = require('fs');
const path = require('path');

const today = new Date().toISOString().slice(0, 10).replace(/-/g, '');
const hostTag = 'wooking-win';

const hermesMemDir = path.join(process.env.USERPROFILE || process.env.HOME, '.hermes', 'memories');
const nutstoreBackupDir = path.join(
  process.env.USERPROFILE || process.env.HOME,
  'Nutstore', '1', 'myNutstore', 'hermes-sync', 'hermes-backups'
);

fs.mkdirSync(nutstoreBackupDir, { recursive: true });

let count = 0;

['MEMORY.md', 'USER.md'].forEach(f => {
  const src = path.join(hermesMemDir, f);
  if (fs.existsSync(src)) {
    const type = f.replace('.md', '');
    const dst = path.join(nutstoreBackupDir, `${hostTag}_${type}_${today}.md`);
    fs.copyFileSync(src, dst);
    console.log(`Backed up: ${dst}`);
    count++;
  }
});

console.log(`Memory backup complete: ${count} files.`);

// Clean up old backups older than 90 days
const maxAge = 90 * 24 * 60 * 60 * 1000;
const now = Date.now();
let cleaned = 0;

fs.readdirSync(nutstoreBackupDir).forEach(f => {
  if (f.startsWith(hostTag) && f.endsWith('.md')) {
    const fp = path.join(nutstoreBackupDir, f);
    const age = now - fs.statSync(fp).mtimeMs;
    if (age > maxAge) {
      fs.unlinkSync(fp);
      cleaned++;
    }
  }
});

if (cleaned > 0) console.log(`Cleaned ${cleaned} old backup(s) (>90 days).`);
