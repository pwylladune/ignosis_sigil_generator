process.env.NODE_ENV = 'test';
import { config } from './config.js';
import { createApp } from './server.js';
import http from 'http';
import { Keypair } from '@solana/web3.js';
import { ReceiptValidatorService } from './services/receiptValidator.js';

async function testBackend() {
  console.log('🧪 RUNNING BACKEND INTEGRATION TEST...');
  const app = createApp();
  const server = http.createServer(app);

  await new Promise<void>((resolve) => server.listen(0, resolve));
  const port = (server.address() as any).port;
  console.log(`Test server running on ephemeral port ${port}`);

  const baseUrl = `http://localhost:${port}`;

  // 1. Health check
  const healthRes: any = await fetch(`${baseUrl}/health`).then((r) => r.json());
  console.log('1. Health check response:', healthRes);
  if (healthRes.status !== 'healthy') throw new Error('Health check failed');

  // 2. Pyre stats start empty (no seeded genesis numbers).
  const statsRes: any = await fetch(`${baseUrl}/api/v1/pyre/stats`).then((r) => r.json());
  console.log('2. Pyre stats response:', statsRes);
  if (!statsRes.success || statsRes.stats.totalBurned !== 0) throw new Error('Pyre stats should start at zero');

  // 3. The crypto starter pack is discontinued: every request gets 410 Gone,
  //    whatever the receipt, and nothing is validated or dispensed.
  const testRecipient = Keypair.generate();
  for (const [platform, receiptData] of [
    ['mock', 'mock_apple_storekit_receipt_token_279_tokens'],
    ['ios', 'sandbox_anything_at_all'],
    ['android', 'any-non-empty-token'],
  ]) {
    const res = await fetch(`${baseUrl}/api/v1/iap/fulfill-starter-pack`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ walletAddress: testRecipient.publicKey.toBase58(), platform, receiptData }),
    });
    const body: any = await res.json();
    console.log(`3. Fulfil (${platform}) -> ${res.status}`, body);
    if (res.status !== 410 || body.success !== false) {
      throw new Error(`Starter pack must be refused for ${platform}`);
    }
  }

  // 3b. The receipt validator itself refuses every platform.
  const validator = new ReceiptValidatorService();
  for (const platform of ['ios', 'android', 'mock'] as const) {
    const v = await validator.verifyReceipt({ platform, receiptData: 'sandbox_x', productId: 'p' });
    if (v.isValid) throw new Error(`Validator must refuse ${platform}`);
  }

  // 4. Pyre writes need the shared secret.
  const burn = {
    signature: '5xIgnosisTestSigBurn93SolanaReceipt42Z',
    practitioner: testRecipient.publicKey.toBase58(),
    amount: 93,
    intentHashHex: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    source: 'mobile_app',
  };
  const post = (headers: Record<string, string>) =>
    fetch(`${baseUrl}/api/v1/pyre/record-burn`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...headers },
      body: JSON.stringify(burn),
    });
  delete process.env.PYRE_WRITE_SECRET;
  if ((await post({})).status !== 503) throw new Error('Writes must be disabled without a secret');
  process.env.PYRE_WRITE_SECRET = 'test-secret';
  if ((await post({ 'x-pyre-secret': 'wrong' })).status !== 401) throw new Error('Wrong secret must be rejected');
  const ok: any = await post({ 'x-pyre-secret': 'test-secret' }).then((r) => r.json());
  console.log('4. Record burn (authorised):', ok);
  if (!ok.success || ok.stats.totalBurned !== 93) throw new Error('Authorised record burn failed');

  // 5. The webhook records only complete events and never invents amounts.
  const hook = (body: unknown, secret = 'test-secret') =>
    fetch(`${baseUrl}/api/v1/pyre/webhook`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-pyre-secret': secret },
      body: JSON.stringify(body),
    }).then((r) => r.json() as Promise<any>);
  const partial = await hook([{ signature: '5xSignatureWithoutAmountOrHash', feePayer: testRecipient.publicKey.toBase58() }]);
  if (partial.recorded !== 0) throw new Error('Webhook must not record events without amount and hash');
  const full = await hook([
    { signature: '5xSignatureComplete000001', feePayer: testRecipient.publicKey.toBase58(), amount: 7, intentHashHex: 'ab'.repeat(32) },
  ]);
  if (full.recorded !== 1) throw new Error('Webhook should record a complete event');
  const stats: any = await fetch(`${baseUrl}/api/v1/pyre/stats`).then((r) => r.json());
  if (stats.stats.totalBurned !== 100) throw new Error(`Expected 100 burned, got ${stats.stats.totalBurned}`);

  // 6. Hardening: JSON errors, bounded limits, no configuration leak.
  const bad = await fetch(`${baseUrl}/api/v1/pyre/record-burn`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-pyre-secret': 'test-secret' },
    body: '{not json',
  });
  const badBody = await bad.text();
  if (bad.status !== 400 || !badBody.startsWith('{')) throw new Error(`Malformed JSON must get a JSON 400, got ${bad.status}`);
  const neg: any = await fetch(`${baseUrl}/api/v1/pyre/recent?limit=-1`).then((r) => r.json());
  if (neg.burns.length !== 0) throw new Error('A negative limit must return nothing');
  const root: any = await fetch(`${baseUrl}/`).then((r) => r.json());
  if ('mintAddress' in root || 'treasuryPublicAddress' in root) throw new Error('Root must not expose configuration');

  server.close();
  await rateLimitTests();
  console.log('✅ Backend fails closed as expected.\n');
}

/**
 * The rate limit is per client: behind one trusted proxy, by the address the
 * proxy appended; with no trusted proxy, X-Forwarded-For is ignored.
 */
async function rateLimitTests() {
  const saved = config.trustProxyHops;
  const hit = async (base: string, forwardedFor: string) => {
    const res = await fetch(`${base}/api/v1/pyre/stats`, { headers: { 'X-Forwarded-For': forwardedFor } });
    return res.status;
  };
  const listen = async () => {
    const s = http.createServer(createApp()).listen(0);
    await new Promise<void>((r) => s.once('listening', () => r()));
    return { s, base: `http://localhost:${(s.address() as any).port}` };
  };
  try {
    // Behind Fly: a client's own spoofed entry comes first; the proxy's last.
    config.trustProxyHops = 1;
    const fly = await listen();
    for (let i = 0; i < 120; i++) {
      if ((await hit(fly.base, `9.9.9.${i % 250}, 203.0.113.1`)) !== 200) throw new Error(`Request ${i + 1} limited too early`);
    }
    if ((await hit(fly.base, '1.1.1.1, 203.0.113.1')) !== 429) throw new Error('A spoofed first entry must not escape the limit');
    if ((await hit(fly.base, '203.0.113.2')) !== 200) throw new Error('Another client must not share the limit');
    fly.s.close();

    // Reached directly: X-Forwarded-For cannot buy a fresh limit.
    config.trustProxyHops = 0;
    const direct = await listen();
    for (let i = 0; i < 120; i++) await hit(direct.base, `198.51.100.${i % 250}`);
    if ((await hit(direct.base, '198.51.100.251')) !== 429) throw new Error('Without a trusted proxy, the header must be ignored');
    direct.s.close();
    console.log('6. Rate limit keyed by the proxied client address, and spoof-proof.');
  } finally {
    config.trustProxyHops = saved;
  }
}

testBackend().catch((e) => {
  console.error('❌ Backend test failed:', e);
  process.exit(1);
});
