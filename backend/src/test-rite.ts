process.env.NODE_ENV = 'test';
import assert from 'node:assert/strict';
import http from 'http';
import os from 'os';
import path from 'path';
import fs from 'fs';
import { DatabaseSync } from 'node:sqlite';
import { Keypair, PublicKey } from '@solana/web3.js';
import { createApp, treasuryOwner } from './server.js';
import { verifyRite } from './services/riteVerifier.js';
import { config } from './config.js';
import {
  JOULE_PROGRAM_ID,
  MEMO_PROGRAM_ID,
  base58,
  clusterProblem,
  commitmentFromMemo,
  isCommitment,
  riteMemo,
} from './services/joule.js';
import { RiteBurnService } from './services/riteBurn.js';
import { FakeChain } from './test-support.js';
import { RiteLedger } from './services/riteLedger.js';
import { PurchaseVerifier } from './routes/rite.js';

/** Joules per rite, as configured. */
const J = config.riteJoules;
const C1 = 'a'.repeat(64);
const C2 = 'b'.repeat(64);

function service(chain: FakeChain, ledger = new RiteLedger(':memory:')) {
  return new RiteBurnService(chain, ledger, { joules: J, pollMs: 1, timeoutMs: 20 });
}

async function unitTests() {
  // Helpers.
  assert.equal(base58(new Uint8Array([0, 0, 1])), '112');
  assert.equal(base58(Buffer.from('hello world')), 'StV1DL6CwTryKyV');
  for (let i = 0; i < 20; i++) {
    const k = Keypair.generate().publicKey;
    assert.equal(base58(k.toBytes()), k.toBase58());
  }
  assert.ok(isCommitment(C1) && !isCommitment('A'.repeat(64)) && !isCommitment('a'.repeat(63)));
  assert.equal(commitmentFromMemo(riteMemo(C1)), C1);
  assert.equal(commitmentFromMemo('IGNOSIS:v1:nothex'), null);
  assert.throws(() => riteMemo('plaintext intent'));
  // The RPC must serve the configured cluster.
  assert.equal(clusterProblem('5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d', 'mainnet-beta'), null);
  assert.equal(clusterProblem('EtWTRABZaYq6iMfeYKouRu166VU2xqa1wcaWoxPkrZBG', 'devnet'), null);
  assert.match(clusterProblem('EtWTRABZaYq6iMfeYKouRu166VU2xqa1wcaWoxPkrZBG', 'mainnet-beta')!, /serves devnet/);
  assert.match(clusterProblem('somethingElse', 'mainnet-beta')!, /unknown cluster/);
  assert.equal(clusterProblem('somethingElse', 'localnet'), null);

  // 1. A purchase burns once; asking again returns the same burn.
  {
    const chain = new FakeChain();
    const s = service(chain);
    const a = await s.fulfil('ios:1', C1);
    assert.deepEqual(a, { status: 'confirmed', signature: 'sig1', joules: J, firstConfirmation: true });
    const b = await s.fulfil('ios:1', C1);
    assert.deepEqual(b, { ...a, firstConfirmation: false });
    assert.equal(chain.totalBurnt(), J);
    assert.equal(chain.prepared, 1);
  }

  // 2. One purchase cannot consecrate a second intent; bad input is refused.
  {
    const chain = new FakeChain();
    const s = service(chain);
    await s.fulfil('ios:2', C1);
    assert.deepEqual(await s.fulfil('ios:2', C2), { status: 'conflict' });
    assert.equal((await s.fulfil('ios:3', 'not hex')).status, 'failed');
    assert.equal((await s.fulfil('', C1)).status, 'failed');
    assert.equal(chain.totalBurnt(), J);
  }

  // 3. A lost send is resent as the same signed burn, never a second one.
  {
    const chain = new FakeChain();
    const s = service(chain);
    chain.dropSends = true;
    assert.deepEqual(await s.fulfil('ios:4', C1), { status: 'pending', signature: 'sig1' });
    chain.dropSends = false;
    assert.equal((await s.fulfil('ios:4', C1)).status, 'confirmed');
    assert.equal(chain.prepared, 1);
    assert.equal(chain.totalBurnt(), J);
  }

  // 4. A burn that expired without landing is rebuilt once.
  {
    const chain = new FakeChain();
    const s = service(chain);
    chain.dropSends = true;
    await s.fulfil('ios:5', C1);
    chain.height += 151;
    chain.dropSends = false;
    assert.deepEqual(await s.fulfil('ios:5', C1), { status: 'confirmed', signature: 'sig2', joules: J, firstConfirmation: true });
    assert.equal(chain.totalBurnt(), J);
  }

  // 5. A burn that landed while we timed out is found, not repeated, even
  //    after its blockhash expires.
  {
    const chain = new FakeChain();
    const s = service(chain);
    chain.hideStatus = true;
    assert.equal((await s.fulfil('ios:6', C1)).status, 'pending');
    chain.hideStatus = false;
    chain.height += 500;
    assert.deepEqual(await s.fulfil('ios:6', C1), { status: 'confirmed', signature: 'sig1', joules: J, firstConfirmation: true });
    assert.equal(chain.prepared, 1);
    assert.equal(chain.totalBurnt(), J);
  }

  // 6. A rejected burn is reported as failed; a retry rebuilds and succeeds.
  {
    const chain = new FakeChain();
    const s = service(chain);
    chain.rejectSends = true;
    assert.equal((await s.fulfil('ios:7', C1)).status, 'failed');
    chain.rejectSends = false;
    assert.equal((await s.fulfil('ios:7', C1)).status, 'confirmed');
    assert.equal(chain.totalBurnt(), J);
  }

  // 7. Concurrent requests for one purchase burn once.
  {
    const chain = new FakeChain();
    const s = service(chain);
    const results = await Promise.all([1, 2, 3, 4].map(() => s.fulfil('ios:8', C1)));
    assert.equal(chain.totalBurnt(), J);
    assert.ok(results.every((r) => r.status !== 'failed' && r.status !== 'conflict'));
    assert.equal(results.filter((r) => r.status === 'confirmed' && r.firstConfirmation).length, 1);
    assert.deepEqual(await s.fulfil('ios:8', C1), { status: 'confirmed', signature: 'sig1', joules: J, firstConfirmation: false });
  }

  // 8. The ledger survives a restart: a new process does not burn again.
  {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rite-ledger-'));
    const file = path.join(dir, 'ledger.sqlite');
    const chain = new FakeChain();
    const ledger1 = new RiteLedger(file);
    chain.dropSends = true;
    await service(chain, ledger1).fulfil('android:9', C1);
    ledger1.close();
    chain.dropSends = false;
    const ledger2 = new RiteLedger(file);
    assert.equal((await service(chain, ledger2).fulfil('android:9', C1)).status, 'confirmed');
    assert.equal(chain.prepared, 1);
    assert.equal(chain.totalBurnt(), J);
    ledger2.close();
    fs.rmSync(dir, { recursive: true, force: true });
  }

  // 9. Many purchases, random faults: never more than one burn per purchase.
  //    Each purchase has its own commitment, so burns are counted per purchase.
  {
    const commit = (p: number) => p.toString(16).padStart(64, '0');
    const chain = new FakeChain();
    const s = service(chain);
    let seed = 7;
    const rand = () => ((seed = (seed * 1103515245 + 12345) % 2 ** 31) / 2 ** 31);
    for (let round = 0; round < 6; round++) {
      for (let p = 0; p < 15; p++) {
        chain.dropSends = rand() < 0.3;
        chain.rejectSends = rand() < 0.1;
        chain.hideStatus = rand() < 0.2;
        if (rand() < 0.2) chain.height += 200;
        await s.fulfil(`web:${p}`, commit(p));
        // The invariant holds after every step, not just at the end.
        assert.ok([...chain.burns.values()].every((j) => j <= J));
      }
    }
    chain.dropSends = chain.rejectSends = chain.hideStatus = false;
    for (let p = 0; p < 15; p++) assert.equal((await s.fulfil(`web:${p}`, commit(p))).status, 'confirmed');
    assert.equal(chain.burns.size, 15);
    assert.ok([...chain.burns.values()].every((j) => j === J));
  }

  // 10. A package of three: concurrent releases of five intents burn three,
  //     and asking again for a spent intent finds its burn.
  {
    const commit = (p: number) => (p + 1).toString(16).padStart(64, '0');
    const chain = new FakeChain();
    const s = service(chain);
    const allowance = { key: 'web:pack', rites: 3 };
    const results = await Promise.all(
      [0, 1, 2, 3, 4].map((p) => s.fulfil(`web:pack#${commit(p)}`, commit(p), allowance))
    );
    assert.equal(results.filter((r) => r.status === 'confirmed').length, 3);
    assert.equal(results.filter((r) => r.status === 'exhausted').length, 2);
    assert.equal(chain.totalBurnt(), 3 * J);
    assert.equal(s.ritesLeft(allowance), 0);
    const spent = results.findIndex((r) => r.status === 'confirmed');
    assert.equal((await s.fulfil(`web:pack#${commit(spent)}`, commit(spent), allowance)).status, 'confirmed');
    assert.equal(chain.totalBurnt(), 3 * J);
  }

  // 11. A ledger made before packages gains their columns and keeps its rows.
  {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rite-ledger-'));
    const file = path.join(dir, 'ledger.sqlite');
    const old = new DatabaseSync(file);
    old.exec(`
      CREATE TABLE rites (purchase_id TEXT PRIMARY KEY, commitment TEXT NOT NULL, state TEXT NOT NULL,
        signature TEXT NOT NULL, last_valid_block_height INTEGER NOT NULL, raw_tx TEXT NOT NULL, updated_at INTEGER NOT NULL);
      CREATE TABLE credits (session_id TEXT PRIMARY KEY, payment_intent TEXT NOT NULL, amount_total INTEGER NOT NULL,
        currency TEXT NOT NULL, state TEXT NOT NULL, created_at INTEGER NOT NULL);
      INSERT INTO credits VALUES ('cs_old', 'pi_old', 100, 'usd', 'paid', 1);`);
    old.close();
    const ledger = new RiteLedger(file);
    assert.equal(ledger.getCredit('cs_old')?.rites, 1);
    assert.equal(ledger.ritesSpent('web:cs_old'), 0);
    ledger.close();
    new RiteLedger(file).close(); // opening again changes nothing
    fs.rmSync(dir, { recursive: true, force: true });
  }
  console.log('✅ Rite fulfilment: one burn per rite under lost, rejected, hidden and concurrent sends; packages capped.');
}

async function routeTests() {
  // Without a mint, treasury and ledger, rites are unavailable.
  {
    const server = http.createServer(createApp()).listen(0);
    const port = (server.address() as any).port;
    const res = await fetch(`http://localhost:${port}/api/v1/rite/consecrate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ platform: 'ios', productId: 'net.ignosis.studio.rite', receiptData: 'x', commitment: C1 }),
    });
    assert.equal(res.status, 503);
    server.close();
  }

  const chain = new FakeChain();
  const burns = service(chain);
  const verifier: PurchaseVerifier = {
    async verifyReceipt({ receiptData, productId }) {
      const ok = receiptData.startsWith('valid:');
      return {
        isValid: ok,
        productId: receiptData.endsWith(':skin') ? 'net.ignosis.studio.skin.cosmic' : productId,
        transactionId: ok ? receiptData.split(':')[1] : '',
        purchaseTime: Date.now(),
        environment: 'sandbox',
      };
    },
  };
  const check = async (sig: string) =>
    sig === '5'.repeat(88)
      ? { valid: true as const, joules: J, commitment: C1, slot: 1, blockTime: null }
      : { valid: false as const, reason: 'Transaction not found' };
  const server = http.createServer(createApp({ verifier, rite: { burns, check } })).listen(0);
  const base = `http://localhost:${(server.address() as any).port}/api/v1`;
  const consecrate = (body: object) =>
    fetch(`${base}/rite/consecrate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ platform: 'ios', productId: 'net.ignosis.studio.rite.pack3', ...body }),
    });

  assert.equal((await consecrate({ receiptData: 'valid:t1', commitment: 'plaintext' })).status, 400);
  assert.equal((await consecrate({ receiptData: 'forged', commitment: C1 })).status, 402);
  assert.equal((await consecrate({ receiptData: 'valid:t2:skin', commitment: C1 })).status, 400);
  assert.equal(chain.totalBurnt(), 0);

  const ok = await consecrate({ receiptData: 'valid:t3', commitment: C1 });
  const body: any = await ok.json();
  assert.equal(ok.status, 200);
  assert.equal(body.signature, 'sig1');
  assert.equal(body.joules, J);
  assert.match(body.explorerUrl, /explorer\.solana\.com\/tx\/sig1/);
  assert.equal(body.remaining, 2);
  const again: any = await consecrate({ receiptData: 'valid:t3', commitment: C1 }).then((r) => r.json());
  assert.equal(again.signature, 'sig1');
  assert.equal(again.remaining, 2);
  assert.equal(chain.totalBurnt(), J);
  // The old single-rite product is no longer sold.
  assert.equal((await consecrate({ receiptData: 'valid:t4', commitment: C2, productId: 'net.ignosis.studio.rite' })).status, 400);

  const stats: any = await fetch(`${base}/pyre/stats`).then((r) => r.json());
  assert.equal(stats.stats.totalBurned, J);

  assert.equal((await fetch(`${base}/rite/not-a-signature`)).status, 400);
  assert.equal((await fetch(`${base}/rite/${'4'.repeat(88)}`)).status, 404);
  const verified: any = await fetch(`${base}/rite/${'5'.repeat(88)}`).then((r) => r.json());
  assert.equal(verified.commitment, C1);

  server.close();

  // A chain that throws (an RPC outage, or a spent treasury allowance) gets a
  // 502, and the server keeps serving: nothing is recorded, so the payer's
  // rite is intact for the next attempt.
  {
    const broken = new FakeChain();
    broken.prepareBurn = async () => {
      throw new Error('The treasury allowance is spent');
    };
    const brokenBurns = service(broken);
    const s2 = http
      .createServer(
        createApp({
          verifier,
          rite: {
            burns: brokenBurns,
            check: async () => {
              throw new Error('RPC down');
            },
          },
        })
      )
      .listen(0);
    const b2 = `http://localhost:${(s2.address() as any).port}/api/v1`;
    const post = () =>
      fetch(`${b2}/rite/consecrate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ platform: 'ios', productId: 'net.ignosis.studio.rite.pack3', receiptData: 'valid:t9', commitment: C1 }),
      });
    assert.equal((await post()).status, 502);
    assert.equal((await post()).status, 502, 'still serving');
    assert.equal((await fetch(`${b2}/rite/${'5'.repeat(88)}`)).status, 502);
    assert.equal(brokenBurns.ritesLeft({ key: 'ios:t9', rites: 3 }), 3);
    s2.close();
  }
  console.log('✅ Rite route: verified purchases only, rite packages only, idempotent, no plaintext, survives a failing chain.');
}

/** The cold owner and the on-chain check (ADR 2026-10-27-ignosis-treasury-cold-owner-hot-delegate). */
async function treasuryTests() {
  const server = Keypair.generate();
  const cold = Keypair.generate().publicKey;
  const saved = { ...config };
  try {
    Object.assign(config, { solanaCluster: 'devnet', treasuryOwner: '' });
    assert.equal(treasuryOwner(server), null, 'devnet: the server key may own the Joules');
    Object.assign(config, { treasuryOwner: cold.toBase58() });
    assert.ok(treasuryOwner(server)?.equals(cold));
    Object.assign(config, { treasuryOwner: 'not a key' });
    assert.equal(treasuryOwner(server), undefined);
    Object.assign(config, { solanaCluster: 'mainnet-beta', treasuryOwner: '' });
    assert.equal(treasuryOwner(server), undefined, 'mainnet: a cold owner is required');
    Object.assign(config, { treasuryOwner: server.publicKey.toBase58() });
    assert.equal(treasuryOwner(server), undefined, 'mainnet: the owner must not be the server key');
    Object.assign(config, { treasuryOwner: cold.toBase58() });
    assert.ok(treasuryOwner(server)?.equals(cold));
  } finally {
    Object.assign(config, saved);
  }

  // The check reads a parsed transaction: a burn by the delegate counts only
  // from the owner's account.
  const mint = Keypair.generate().publicKey;
  const ownerAccount = Keypair.generate().publicKey;
  const otherAccount = Keypair.generate().publicKey;
  const txFrom = (account: PublicKey) => ({
    slot: 7,
    blockTime: null,
    meta: { err: null },
    transaction: {
      message: {
        instructions: [
          {
            programId: JOULE_PROGRAM_ID,
            parsed: {
              type: 'burnChecked',
              info: {
                account: account.toBase58(),
                mint: mint.toBase58(),
                authority: server.publicKey.toBase58(),
                tokenAmount: { amount: String(J) },
              },
            },
          },
          { programId: MEMO_PROGRAM_ID, parsed: riteMemo(C1) },
        ],
      },
    },
  });
  const chainWith = (tx: object) => ({ getParsedTransaction: async () => tx }) as any;
  const good = await verifyRite(chainWith(txFrom(ownerAccount)), 'sig', mint, server.publicKey, ownerAccount);
  assert.deepEqual(good, { valid: true, joules: J, commitment: C1, slot: 7, blockTime: null });
  const elsewhere = await verifyRite(chainWith(txFrom(otherAccount)), 'sig', mint, server.publicKey, ownerAccount);
  assert.equal(elsewhere.valid, false);
  console.log('✅ Treasury: mainnet needs a cold owner; rites count only from its account.');
}

unitTests()
  .then(routeTests)
  .then(treasuryTests)
  .catch((e) => {
    console.error('❌ Rite test failed:', e);
    process.exit(1);
  });
