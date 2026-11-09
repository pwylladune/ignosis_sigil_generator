/**
 * Writes a consistent copy of the rite ledger, safe while the server runs.
 *
 *   node dist/tools/ledgerSnapshot.js <destination.sqlite>
 *
 * Environment:
 *   RITE_LEDGER_PATH  the live ledger
 *
 * The ledger is the only record of which paid rites are spent, and its volume
 * is not replicated: copy the snapshot off the machine (the ledger-backup
 * workflow does). It holds Checkout session IDs, which spend rites: keep
 * copies encrypted. Opens the ledger read-only and changes nothing in it.
 */
import fs from 'node:fs';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';

function main() {
  const source = process.env.RITE_LEDGER_PATH;
  const destination = process.argv[2];
  if (!source || !destination) throw new Error('Usage: RITE_LEDGER_PATH=<ledger> ledgerSnapshot <destination>');
  if (path.resolve(source) === path.resolve(destination)) throw new Error('The destination is the ledger itself');
  if (!fs.existsSync(source)) throw new Error(`No ledger at ${source}`);

  fs.mkdirSync(path.dirname(path.resolve(destination)), { recursive: true });
  // VACUUM INTO refuses to overwrite: write beside the destination, then move.
  const partial = `${destination}.partial`;
  fs.rmSync(partial, { force: true });
  const live = new DatabaseSync(source, { readOnly: true });
  try {
    live.exec('PRAGMA busy_timeout = 5000');
    live.prepare('VACUUM INTO ?').run(partial);
  } finally {
    live.close();
  }

  const copy = new DatabaseSync(partial, { readOnly: true });
  let rites: number, credits: number;
  try {
    const check = copy.prepare('PRAGMA integrity_check').get() as any;
    if (check?.integrity_check !== 'ok') throw new Error(`The copy failed its integrity check: ${check?.integrity_check}`);
    rites = Number((copy.prepare('SELECT COUNT(*) AS n FROM rites').get() as any).n);
    credits = Number((copy.prepare('SELECT COUNT(*) AS n FROM credits').get() as any).n);
  } finally {
    copy.close();
  }
  fs.renameSync(partial, destination);
  console.log(`Snapshot: ${destination} (${fs.statSync(destination).size} bytes, ${credits} payments, ${rites} rites)`);
}

try {
  main();
} catch (e: any) {
  console.error(e.message);
  process.exit(1);
}
