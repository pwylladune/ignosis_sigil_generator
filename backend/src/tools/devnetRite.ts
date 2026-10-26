/**
 * End-to-end rite on devnet, through the real HTTP route and the real chain.
 * Only the store is stood in for: this tool injects a purchase verifier that
 * accepts its own test receipts. The server itself has no such bypass.
 *
 *   JOULE_MINT_ADDRESS=... TREASURY_KEYPAIR_PATH=... npm run test:devnet
 *
 * Checks: the burn confirms; the on-chain check finds the commitment; supply
 * falls by exactly the rite's joules; a retry does not burn again; and the
 * chain refuses to transfer a Joule to anyone.
 */
process.env.NODE_ENV = 'test';
import assert from 'node:assert/strict';
import { createHash, randomBytes } from 'crypto';
import * as fs from 'fs';
import http from 'http';
import os from 'os';
import path from 'path';
import { Connection, Keypair, PublicKey, Transaction, sendAndConfirmTransaction } from '@solana/web3.js';
import {
  createAssociatedTokenAccountIdempotentInstruction,
  createTransferCheckedInstruction,
  getAssociatedTokenAddressSync,
  getMint,
} from '@solana/spl-token';
import { createApp } from '../server.js';
import { config } from '../config.js';
import { JOULE_DECIMALS, JOULE_PROGRAM_ID } from '../services/joule.js';
import { RiteBurnService, SolanaRiteChain } from '../services/riteBurn.js';
import { RiteLedger } from '../services/riteLedger.js';
import { verifyRite } from '../services/riteVerifier.js';

/** The device-side commitment: SHA-256("IGNOSIS:v1" ‖ salt ‖ UTF-8(intent)). */
function commit(intent: string, salt: Buffer): string {
  return createHash('sha256').update('IGNOSIS:v1').update(salt).update(intent, 'utf8').digest('hex');
}

async function main() {
  const rpcUrl = process.env.SOLANA_RPC_URL || 'https://api.devnet.solana.com';
  if (!rpcUrl.includes('devnet') && !/localhost|127\.0\.0\.1/.test(rpcUrl)) throw new Error('Devnet or local only');
  const connection = new Connection(rpcUrl, 'confirmed');
  const mint = new PublicKey(process.env.JOULE_MINT_ADDRESS || '');
  const treasury = Keypair.fromSecretKey(
    Uint8Array.from(JSON.parse(fs.readFileSync(process.env.TREASURY_KEYPAIR_PATH || 'treasury.keypair.json', 'utf8')))
  );

  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rite-devnet-'));
  const ledger = new RiteLedger(path.join(dir, 'ledger.sqlite'));
  const burns = new RiteBurnService(new SolanaRiteChain(connection, treasury, mint), ledger, {
    joules: config.riteJoules,
  });
  const check = (sig: string) => verifyRite(connection, sig, mint, treasury.publicKey);
  const app = createApp({
    rite: { burns, check },
    verifier: {
      async verifyReceipt({ receiptData, productId }) {
        const ok = receiptData.startsWith('devnet-test:');
        return {
          isValid: ok,
          productId,
          transactionId: ok ? receiptData : '',
          purchaseTime: Date.now(),
          environment: 'sandbox',
        };
      },
    },
  });
  const server = http.createServer(app).listen(0);
  const base = `http://localhost:${(server.address() as any).port}/api/v1/rite`;

  const intent = 'I am free of the fear of the open road';
  const salt = randomBytes(32);
  const commitment = commit(intent, salt);
  const purchase = `devnet-test:${Date.now()}`;
  const supplyBefore = (await getMint(connection, mint, 'confirmed', JOULE_PROGRAM_ID)).supply;

  const consecrate = () =>
    fetch(`${base}/consecrate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ platform: 'web', productId: 'net.ignosis.studio.rite', receiptData: purchase, commitment }),
    }).then(async (r) => ({ status: r.status, body: (await r.json()) as any }));

  const first = await consecrate();
  console.log('Consecrate:', first.status, first.body);
  assert.equal(first.status, 200);

  const verified: any = await fetch(`${base}/${first.body.signature}`).then((r) => r.json());
  console.log('On-chain check:', verified);
  assert.equal(verified.success, true);
  assert.equal(verified.commitment, commitment);
  assert.equal(verified.joules, config.riteJoules);
  // Only the holder of the salt and intent can show the burn is theirs.
  assert.equal(commit(intent, salt), verified.commitment);
  assert.notEqual(commit(intent, randomBytes(32)), verified.commitment);

  const supplyAfter = (await getMint(connection, mint, 'confirmed', JOULE_PROGRAM_ID)).supply;
  console.log(`Supply: ${supplyBefore} -> ${supplyAfter}`);
  assert.equal(supplyBefore - supplyAfter, BigInt(config.riteJoules));

  const again = await consecrate();
  assert.equal(again.body.signature, first.body.signature);
  assert.equal((await getMint(connection, mint, 'confirmed', JOULE_PROGRAM_ID)).supply, supplyAfter);
  console.log('Retry: same burn, supply unchanged.');

  // The chain itself must refuse to move a Joule to anyone.
  const stranger = Keypair.generate().publicKey;
  const from = getAssociatedTokenAddressSync(mint, treasury.publicKey, false, JOULE_PROGRAM_ID);
  const to = getAssociatedTokenAddressSync(mint, stranger, false, JOULE_PROGRAM_ID);
  await assert.rejects(
    sendAndConfirmTransaction(
      connection,
      new Transaction().add(
        createAssociatedTokenAccountIdempotentInstruction(treasury.publicKey, to, stranger, mint, JOULE_PROGRAM_ID),
        createTransferCheckedInstruction(from, mint, to, treasury.publicKey, 1, JOULE_DECIMALS, [], JOULE_PROGRAM_ID)
      ),
      [treasury]
    ),
    // Token-2022 error 0x25 (37) is NonTransferable.
    /custom program error: 0x25\b/
  );
  console.log('Transfer of a Joule: refused by the chain.');

  server.close();
  ledger.close();
  fs.rmSync(dir, { recursive: true, force: true });
  console.log(`\n✅ Rite verified on ${rpcUrl}: ${first.body.explorerUrl}`);
}

main().catch((e) => {
  console.error('❌ Devnet rite failed:', e);
  process.exit(1);
});
