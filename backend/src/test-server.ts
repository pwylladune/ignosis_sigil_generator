process.env.NODE_ENV = 'test';
import { createApp } from './server.js';
import http from 'http';
import { Keypair } from '@solana/web3.js';

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

  // 2. Pyre Stats
  const statsRes: any = await fetch(`${baseUrl}/api/v1/pyre/stats`).then((r) => r.json());
  console.log('2. Pyre stats response:', statsRes);
  if (!statsRes.success) throw new Error('Pyre stats failed');

  // 3. Fulfill Starter Pack (Mock IAP)
  const testRecipient = Keypair.generate();
  const fulfillRes: any = await fetch(`${baseUrl}/api/v1/iap/fulfill-starter-pack`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      walletAddress: testRecipient.publicKey.toBase58(),
      platform: 'mock',
      receiptData: 'mock_apple_storekit_receipt_token_279_tokens',
      productId: 'com.ignosis.pack.ignition_279',
    }),
  }).then((r) => r.json());
  console.log('3. IAP Fulfill Starter Pack response:', fulfillRes);
  if (!fulfillRes.success || fulfillRes.tokensDispatched !== 279) {
    throw new Error('Fulfill starter pack failed');
  }

  // 4. Record a Consecrated Burn
  const burnRes: any = await fetch(`${baseUrl}/api/v1/pyre/record-burn`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      signature: '5xIgnosisTestSigBurn93SolanaReceipt42Z',
      practitioner: testRecipient.publicKey.toBase58(),
      amount: 93,
      intentHashHex: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      source: 'mobile_app',
    }),
  }).then((r) => r.json());
  console.log('4. Record burn response:', burnRes);
  if (!burnRes.success) throw new Error('Record burn failed');

  server.close();
  console.log('✅ ALL BACKEND TESTS PASSED CLEANLY!\n');
}

testBackend().catch((e) => {
  console.error('❌ Backend test failed:', e);
  process.exit(1);
});
