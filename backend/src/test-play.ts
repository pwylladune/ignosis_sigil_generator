process.env.NODE_ENV = 'test';
import assert from 'node:assert/strict';
import { createVerify, generateKeyPairSync } from 'crypto';
import http from 'http';
import { config } from './config.js';
import { createApp, routingVerifier } from './server.js';
import { ReceiptValidatorService } from './services/receiptValidator.js';
import { RiteBurnService } from './services/riteBurn.js';
import { RiteLedger } from './services/riteLedger.js';
import { GooglePlayGateway, PlayGateway, PlayPurchase, PlayVoidedSync } from './services/playRite.js';
import { FakeChain } from './test-support.js';

const J = config.riteJoules;
/** A package of three rites. */
const RITE = 'net.ignosis.studio.rite.pack3';
const C1 = 'e'.repeat(64);
const C2 = 'f'.repeat(64);
const C3 = '3'.repeat(64);
const C4 = '4'.repeat(64);
const token = (n: number) => `play-token-${'x'.repeat(30)}-${n}`;

/** Google Play as the app's purchases leave it; tests change purchases in place. */
class FakePlay implements PlayGateway {
  purchases = new Map<string, PlayPurchase>();
  acknowledged: string[] = [];
  voided: string[] = [];

  /** A license-tester purchase, completed, not consumed, not acknowledged. */
  buy(n: number, overrides: Partial<PlayPurchase> = {}) {
    this.purchases.set(token(n), {
      purchaseState: 0,
      consumptionState: 0,
      acknowledgementState: 0,
      orderId: `GPA.0000-0000-0000-000${n}`,
      purchaseType: 0,
      ...overrides,
    });
  }
  /** Purchases of a package other than [RITE]. */
  productOf = new Map<string, string>();
  async getPurchase(productId: string, purchaseToken: string) {
    return productId === (this.productOf.get(purchaseToken) ?? RITE) ? this.purchases.get(purchaseToken) ?? null : null;
  }
  async acknowledge(_productId: string, purchaseToken: string) {
    this.acknowledged.push(purchaseToken);
    this.purchases.get(purchaseToken)!.acknowledgementState = 1;
  }
  async voidedOrderIds() {
    return this.voided;
  }
}

async function routeTests() {
  const chain = new FakeChain();
  const ledger = new RiteLedger(':memory:');
  const burns = new RiteBurnService(chain, ledger, { joules: J, pollMs: 1, timeoutMs: 20 });
  const play = new FakePlay();
  const rite = { burns, check: null, play: { gateway: play, ledger } };
  const server = http.createServer(createApp({ rite })).listen(0);
  const base = `http://localhost:${(server.address() as any).port}/api/v1`;
  const consecrate = (receiptData: string, commitment: string, productId = RITE) =>
    fetch(`${base}/rite/consecrate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ platform: 'android', productId, receiptData, commitment }),
    }).then(async (r) => ({ status: r.status, body: (await r.json()) as any }));

  // 1. Unknown, pending and cancelled purchases, and other products, buy nothing.
  assert.equal((await consecrate(token(1), C1)).status, 402);
  play.buy(2, { purchaseState: 2 });
  play.buy(3, { purchaseState: 1 });
  assert.equal((await consecrate(token(2), C1)).status, 402);
  assert.equal((await consecrate(token(3), C1)).status, 402);
  play.buy(4);
  assert.equal((await consecrate(token(4), C1, 'net.ignosis.studio.skin.cosmic')).status, 402);
  assert.equal((await consecrate('short', C1)).status, 402);
  assert.equal(chain.totalBurnt(), 0);

  // 2. Off mainnet, real money is refused: only license-tester purchases count.
  play.buy(5, { purchaseType: undefined });
  assert.equal((await consecrate(token(5), C1)).status, 402);

  // 3. A completed test purchase of three rites burns three times, once per
  //    intent, and is acknowledged; asking again for an intent finds its burn.
  const ok = await consecrate(token(4), C1);
  assert.equal(ok.status, 200);
  assert.equal(ok.body.joules, J);
  assert.equal(ok.body.remaining, 2);
  assert.deepEqual(play.acknowledged, [token(4)]);
  assert.equal((await consecrate(token(4), C1)).body.signature, ok.body.signature);
  assert.equal((await consecrate(token(4), C2)).body.remaining, 1);
  assert.equal((await consecrate(token(4), C3)).body.remaining, 0);
  const fourth = await consecrate(token(4), C4);
  assert.equal(fourth.status, 409);
  assert.equal(fourth.body.exhausted, true);
  assert.equal(chain.totalBurnt(), 3 * J);

  // 4. After the app consumes it, the same token still finds its own burns,
  //    and buys nothing more; a consumed token never spent buys nothing.
  play.purchases.get(token(4))!.consumptionState = 1;
  assert.equal((await consecrate(token(4), C1)).body.signature, ok.body.signature);
  assert.equal((await consecrate(token(4), C4)).status, 409);
  play.buy(6, { consumptionState: 1 });
  assert.equal((await consecrate(token(6), C1)).status, 402);
  assert.equal(chain.totalBurnt(), 3 * J);

  // 5. A refund reported by Play revokes a package's unused rites; burns made stay.
  play.buy(7);
  assert.equal((await consecrate(token(7), C1)).status, 200, 'credited before the refund is known');
  play.buy(8);
  await consecrate(token(8), 'not hex'); // rejected by the body schema, nothing recorded
  ledger.recordCredit({
    sessionId: 'GPA.0000-0000-0000-0008', paymentIntent: 'GPA.0000-0000-0000-0008', amountTotal: 0, currency: '', rites: 3,
  });
  play.voided = ['GPA.0000-0000-0000-0007', 'GPA.0000-0000-0000-0008'];
  assert.equal(await new PlayVoidedSync(play, ledger).runOnce(), 2);
  assert.equal((await consecrate(token(8), C1)).status, 402);
  assert.equal((await consecrate(token(7), C2)).status, 402);
  assert.equal(chain.totalBurnt(), 4 * J);

  // 6. Each package buys its own count of rites.
  play.buy(11);
  play.productOf.set(token(11), 'net.ignosis.studio.rite.pack7');
  const seven = await consecrate(token(11), C1, 'net.ignosis.studio.rite.pack7');
  assert.equal(seven.body.remaining, 6);
  assert.equal((await consecrate(token(11), C2, RITE)).status, 402, 'the token is checked against its own product');
  server.close();

  // 7. On mainnet it is the other way round: test purchases are refused.
  const saved = config.solanaCluster;
  Object.assign(config, { solanaCluster: 'mainnet-beta' });
  const mainnet = routingVerifier(rite, new ReceiptValidatorService());
  play.buy(9);
  play.buy(10, { purchaseType: undefined });
  assert.equal((await mainnet.verifyReceipt({ platform: 'android', receiptData: token(9), productId: RITE })).isValid, false);
  assert.equal((await mainnet.verifyReceipt({ platform: 'android', receiptData: token(10), productId: RITE })).isValid, true);
  Object.assign(config, { solanaCluster: saved });

  // 8. Without Google Play configured, Android rites are refused.
  const none = routingVerifier({ burns, check: null }, new ReceiptValidatorService());
  assert.equal((await none.verifyReceipt({ platform: 'android', receiptData: token(9), productId: RITE })).isValid, false);
}

/** The real gateway against a stubbed Google: its JWT must verify with the account's public key. */
async function gatewayTests() {
  const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const account = JSON.stringify({
    client_email: 'rite@ignosis-test.iam.gserviceaccount.com',
    private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }),
  });
  const realFetch = globalThis.fetch;
  const calls: string[] = [];
  let tokenRequests = 0;
  globalThis.fetch = (async (input: any, init?: any) => {
    const url = String(input);
    calls.push(`${init?.method ?? 'GET'} ${url}`);
    if (url === 'https://oauth2.googleapis.com/token') {
      tokenRequests++;
      const assertion = new URLSearchParams(init.body).get('assertion')!;
      const [h, c, s] = assertion.split('.');
      assert.ok(createVerify('RSA-SHA256').update(`${h}.${c}`).verify(publicKey, Buffer.from(s, 'base64url')));
      const claims = JSON.parse(Buffer.from(c, 'base64url').toString());
      assert.equal(claims.scope, 'https://www.googleapis.com/auth/androidpublisher');
      assert.equal(claims.iss, 'rite@ignosis-test.iam.gserviceaccount.com');
      return new Response(JSON.stringify({ access_token: 'ya29.test', expires_in: 3600 }), { status: 200 });
    }
    assert.equal(init?.headers?.Authorization, 'Bearer ya29.test');
    if (url.includes('/tokens/missing')) return new Response('{}', { status: 410 });
    if (url.includes('voidedpurchases')) {
      return new Response(
        JSON.stringify(
          url.includes('token=p2')
            ? { voidedPurchases: [{ orderId: 'GPA.B' }] }
            : { voidedPurchases: [{ orderId: 'GPA.A' }], tokenPagination: { nextPageToken: 'p2' } }
        ),
        { status: 200 }
      );
    }
    if (url.endsWith(':acknowledge')) return new Response(null, { status: 204 });
    return new Response(JSON.stringify({ purchaseState: 0, consumptionState: 0, acknowledgementState: 0, orderId: 'GPA.A', purchaseType: 0 }), { status: 200 });
  }) as typeof fetch;
  try {
    const g = new GooglePlayGateway(account, 'net.ignosis.studio');
    assert.deepEqual(await g.getPurchase(RITE, 'tok'), {
      purchaseState: 0, consumptionState: 0, acknowledgementState: 0, orderId: 'GPA.A', purchaseType: 0,
    });
    assert.equal(await g.getPurchase(RITE, 'missing'), null);
    await g.acknowledge(RITE, 'tok');
    assert.deepEqual(await g.voidedOrderIds(0), ['GPA.A', 'GPA.B']);
    assert.equal(tokenRequests, 1, 'the access token is reused until it nears expiry');
    assert.ok(calls.some((c) => c.startsWith(`GET https://androidpublisher.googleapis.com/androidpublisher/v3/applications/net.ignosis.studio/purchases/products/${RITE}/tokens/tok`)));
    assert.ok(calls.some((c) => c.startsWith('POST') && c.endsWith('/tokens/tok:acknowledge')));
    assert.throws(() => new GooglePlayGateway('{}', 'net.ignosis.studio'));
  } finally {
    globalThis.fetch = realFetch;
  }
}

routeTests()
  .then(gatewayTests)
  .then(() => console.log('✅ Play: completed test purchases only off mainnet, acknowledged, one burn per rite up to the package, refunds revoke unused rites.'))
  .catch((e) => {
    console.error('❌ Play test failed:', e);
    process.exit(1);
  });
