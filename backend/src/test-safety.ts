process.env.NODE_ENV = 'test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { config } from './config.js';
import { RiteDeps, createApp, shutDown } from './server.js';
import { PlayGateway } from './services/playRite.js';
import { RiteBurnService } from './services/riteBurn.js';
import { RiteLedger } from './services/riteLedger.js';
import { RiteSweeper } from './services/riteSweeper.js';
import { PaidSession, StripeGateway } from './services/stripeRite.js';
import { FakeChain } from './test-support.js';
import { treasuryProblems } from './tools/treasuryStatus.js';

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ignosis-safety-'));
const C1 = 'a'.repeat(64);
const SESSION = `cs_test_${'s'.repeat(24)}`;
const PAID: PaidSession = { sessionId: SESSION, paymentIntent: 'pi_1', amountTotal: 314, currency: 'usd', rites: 7 };

/** Stripe that can be down (throws) or simply not know a session (null). */
class FlakyStripe implements StripeGateway {
  readonly live = false;
  down = false;
  paid = new Map<string, PaidSession>();
  async createCheckout() {
    return { id: SESSION, url: 'https://checkout.stripe.com/c/pay/x' };
  }
  async offers() {
    return [];
  }
  async retrievePaid(sessionId: string) {
    if (this.down) throw new Error('Stripe is unreachable');
    return this.paid.get(sessionId) ?? null;
  }
  parseWebhook(): never {
    throw new Error('unused');
  }
}

const playDown: PlayGateway = {
  getPurchase: async () => {
    throw new Error('Play purchase lookup failed (503)');
  },
  acknowledge: async () => {},
  voidedOrderIds: async () => [],
};

async function listen(app: ReturnType<typeof createApp>) {
  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, resolve));
  return { server, base: `http://localhost:${(server.address() as any).port}` };
}

const consecrate = (base: string, body: object) =>
  fetch(`${base}/api/v1/rite/consecrate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

async function main() {
  // 1. The ledger runs in WAL mode, snapshots while open, and closes cleanly.
  {
    const file = path.join(dir, 'ledger.sqlite');
    const ledger = new RiteLedger(file);
    const probe = new DatabaseSync(file, { readOnly: true });
    assert.equal((probe.prepare('PRAGMA journal_mode').get() as any).journal_mode, 'wal');
    probe.close();

    ledger.recordCredit(PAID);
    assert.ok(ledger.insertPending({ purchaseId: 'p1', commitment: C1, signature: 's1', lastValidBlockHeight: 9, rawTx: 'x' }));
    const copy = path.join(dir, 'copy.sqlite');
    ledger.snapshot(copy);
    // A burn recorded after the snapshot is not in it; everything before is.
    assert.ok(ledger.insertPending({ purchaseId: 'p2', commitment: C1, signature: 's2', lastValidBlockHeight: 9, rawTx: 'x' }));
    const restored = new RiteLedger(copy);
    assert.equal(restored.getCredit(SESSION)?.rites, 7);
    assert.equal(restored.get('p1')?.signature, 's1');
    assert.equal(restored.get('p2'), undefined);
    restored.close();
    assert.throws(() => ledger.snapshot(copy), 'a snapshot never overwrites a file');

    // The snapshot tool: a second process, while the server's ledger is open.
    const out = path.join(dir, 'backup', 'tool.sqlite');
    const tool = path.join(path.dirname(process.argv[1]), 'tools', 'ledgerSnapshot.js');
    const run = () =>
      execFileSync(process.execPath, [tool, out], { env: { ...process.env, RITE_LEDGER_PATH: file }, encoding: 'utf8' });
    assert.match(run(), /1 payments, 2 rites/);
    assert.match(run(), /1 payments, 2 rites/, 'a second run replaces the first snapshot');
    assert.ok(!fs.existsSync(`${out}.partial`));
    const fromTool = new RiteLedger(out);
    assert.equal(fromTool.get('p2')?.signature, 's2');
    fromTool.close();
    assert.throws(() =>
      execFileSync(process.execPath, [tool, file], { env: { ...process.env, RITE_LEDGER_PATH: file }, stdio: 'pipe' })
    );

    ledger.close();
    ledger.close(); // Twice is safe.
    assert.ok(!fs.existsSync(`${file}-wal`) || fs.statSync(`${file}-wal`).size === 0, 'the log is folded in on close');
    const reopened = new RiteLedger(file);
    assert.equal(reopened.ritesSpent('nothing'), 0);
    assert.equal(reopened.get('p2')?.signature, 's2');
    reopened.close();
    console.log('1. Ledger: WAL, live snapshots (method and tool), clean close.');
  }

  // 2. A store that cannot be reached is "try again" (502), never "refused"
  //    (402): the app drops a package on a refusal.
  {
    const ledger = new RiteLedger(':memory:');
    const chain = new FakeChain();
    const burns = new RiteBurnService(chain, ledger, { joules: config.riteJoules });
    const gateway = new FlakyStripe();
    const rite: RiteDeps = { burns, check: null, ledger, stripe: { gateway, ledger }, play: { gateway: playDown, ledger } };
    const { server, base } = await listen(createApp({ rite }));
    const web = { platform: 'web', productId: 'x', receiptData: SESSION, commitment: C1 };

    // Paid, but the webhook has not arrived and Stripe is down.
    gateway.paid.set(SESSION, PAID);
    gateway.down = true;
    let res = await consecrate(base, web);
    assert.equal(res.status, 502, 'a Stripe outage must not read as a refusal');
    assert.equal(chain.sends, 0);

    // Stripe is back: the same request burns.
    gateway.down = false;
    res = await consecrate(base, web);
    assert.equal(res.status, 200);
    assert.equal(((await res.json()) as any).remaining, 6);

    // Once the credit is in the ledger, a Stripe outage no longer matters.
    gateway.down = true;
    res = await consecrate(base, { ...web, commitment: 'b'.repeat(64) });
    assert.equal(res.status, 200);

    // A session Stripe does not know is still a plain refusal.
    gateway.down = false;
    res = await consecrate(base, { ...web, receiptData: `cs_test_${'u'.repeat(24)}` });
    assert.equal(res.status, 402);

    // Play down: 502 as well.
    res = await consecrate(base, { platform: 'android', productId: 'net.ignosis.studio.rite.pack7', receiptData: 't'.repeat(40), commitment: C1 });
    assert.ok(res.status === 502 || res.status === 402, `unexpected ${res.status}`);
    const android = res.status;
    server.close();
    ledger.close();
    assert.equal(android, 502, 'a Play outage must not read as a refusal');
    console.log('2. Store outages answer 502 (try again); unknown payments still 402.');
  }

  // 3. Shutdown: an open request finishes, timers stop, the ledger closes.
  {
    const ledger = new RiteLedger(path.join(dir, 'shutdown.sqlite'));
    const burns = new RiteBurnService(new FakeChain(), ledger, { joules: config.riteJoules });
    const sweeper = new RiteSweeper(burns, ledger, { intervalMs: 5 });
    sweeper.start();
    let finished = false;
    const server = http.createServer((_req, res) => {
      setTimeout(() => {
        finished = true;
        res.end('done');
      }, 150);
    });
    await new Promise<void>((resolve) => server.listen(0, resolve));
    const slow = fetch(`http://localhost:${(server.address() as any).port}/`).then((r) => r.text());
    await new Promise((r) => setTimeout(r, 30));
    await shutDown(server, { burns, check: null, ledger, sweeper });
    assert.ok(finished, 'the open request was allowed to finish');
    assert.equal(await slow, 'done');
    assert.equal(server.listening, false);
    assert.throws(() => ledger.get('p1'), 'the ledger is closed');

    // A request that never ends is cut off after the grace period.
    const stuck = http.createServer(() => {});
    await new Promise<void>((resolve) => stuck.listen(0, resolve));
    const hung = fetch(`http://localhost:${(stuck.address() as any).port}/`).catch(() => 'cut');
    await new Promise((r) => setTimeout(r, 30));
    const saved = console.error;
    console.error = () => {};
    const t0 = Date.now();
    await shutDown(stuck, { burns: null, check: null }, 100);
    console.error = saved;
    assert.ok(Date.now() - t0 < 2000);
    assert.equal(await hung, 'cut');
    console.log('3. Shutdown: open requests finish (or are cut after the grace), the ledger closes.');
  }

  // 4. The treasury check names each way the server could stop burning.
  {
    const ok = { delegateIsServer: true, rites: 500n, feeBurns: 16000, minFeeBurns: 2000 };
    assert.deepEqual(treasuryProblems(ok), []);
    assert.equal(treasuryProblems({ ...ok, rites: 99n }).length, 1);
    assert.equal(treasuryProblems({ ...ok, feeBurns: 1999 }).length, 1);
    assert.match(treasuryProblems({ ...ok, delegateIsServer: false, rites: 0n })[0], /not the delegate/);
    assert.equal(treasuryProblems({ delegateIsServer: false, rites: 0n, feeBurns: 0, minFeeBurns: 2000 }).length, 2);
    console.log('4. Treasury check: low allowance, low SOL and a wrong delegate each fail it.');
  }

  fs.rmSync(dir, { recursive: true, force: true });
  console.log('✅ Safety: durable ledger with live snapshots, outages are not refusals, clean shutdown, treasury check.');
}

main().catch((e) => {
  console.error('❌ Safety test failed:', e);
  process.exit(1);
});
