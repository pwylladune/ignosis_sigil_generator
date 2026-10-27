process.env.NODE_ENV = 'test';
import assert from 'node:assert/strict';
import http from 'http';
import Stripe from 'stripe';
import { config } from './config.js';
import { createApp, stripeFromConfig } from './server.js';
import { RiteBurnService } from './services/riteBurn.js';
import { RiteLedger } from './services/riteLedger.js';
import { RiteSweeper } from './services/riteSweeper.js';
import { RitePack } from './services/ritePacks.js';
import { PackOffer, PaidSession, RITE_METADATA, StripeGateway } from './services/stripeRite.js';
import { FakeChain } from './test-support.js';

const J = config.riteJoules;
const C1 = 'c'.repeat(64);
const C2 = 'd'.repeat(64);
const C3 = '3'.repeat(64);
const C4 = '4'.repeat(64);
/** The [k]th of many distinct commitments. */
const C = (k: number) => k.toString(16).padStart(64, 'e');
const WHSEC = 'whsec_test_ignosis';
const stripe = new Stripe('sk_test_offline');
const session = (n: number) => `cs_test_${'a'.repeat(20)}${n}`;

/** Stripe's Checkout and lookup are faked; webhook signatures are verified for real. */
class FakeStripe implements StripeGateway {
  constructor(readonly live = false) {}
  created = 0;
  /** The package each session was opened for. */
  packs: string[] = [];
  /** Sessions Stripe would report as paid if asked directly. */
  paid = new Map<string, PaidSession>();
  async createCheckout(pack: RitePack) {
    const id = session(++this.created);
    this.packs.push(pack.id);
    return { id, url: `https://checkout.stripe.com/c/pay/${id}` };
  }
  async offers(): Promise<PackOffer[]> {
    return [{ id: 'pack7', rites: 7, amount: 314, currency: 'usd' }];
  }
  async retrievePaid(sessionId: string) {
    return this.paid.get(sessionId) ?? null;
  }
  parseWebhook(rawBody: Buffer, signature: string) {
    return stripe.webhooks.constructEvent(rawBody, signature, WHSEC);
  }
}

function sessionEvent(type: string, id: string, overrides: Partial<Stripe.Checkout.Session> = {}) {
  return {
    id: `evt_${Math.random().toString(36).slice(2)}`,
    object: 'event',
    livemode: false,
    type,
    data: {
      object: {
        id,
        object: 'checkout.session',
        mode: 'payment',
        payment_status: 'paid',
        payment_intent: `pi_${id}`,
        amount_total: 777,
        currency: 'usd',
        metadata: { ...RITE_METADATA, pack: 'pack7' },
        ...overrides,
      },
    },
  };
}

const chargeEvent = (type: string, paymentIntent: string) => ({
  id: `evt_${Math.random().toString(36).slice(2)}`,
  object: 'event',
  livemode: false,
  type,
  data: { object: { id: `ch_${paymentIntent}`, object: 'charge', payment_intent: paymentIntent } },
});

async function main() {
  const chain = new FakeChain();
  const ledger = new RiteLedger(':memory:');
  const burns = new RiteBurnService(chain, ledger, { joules: J, pollMs: 1, timeoutMs: 20 });
  const gateway = new FakeStripe();
  const sweeper = new RiteSweeper(burns, ledger, { minAgeMs: 0 });
  const server = http
    .createServer(createApp({ rite: { burns, check: null, stripe: { gateway, ledger }, sweeper } }))
    .listen(0);
  const base = `http://localhost:${(server.address() as any).port}/api/v1`;

  const hook = (event: object, sign = true) => {
    const payload = JSON.stringify(event);
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (sign) headers['stripe-signature'] = stripe.webhooks.generateTestHeaderString({ payload, secret: WHSEC });
    return fetch(`${base}/stripe/webhook`, { method: 'POST', headers, body: payload });
  };
  const credit = (id: string) => fetch(`${base}/rite/credit/${id}`).then((r) => r.json() as Promise<any>);
  const consecrate = (id: string, commitment: string) =>
    fetch(`${base}/rite/consecrate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ platform: 'web', productId: 'net.ignosis.studio.rite', receiptData: id, commitment }),
    }).then(async (r) => ({ status: r.status, body: (await r.json()) as any }));

  const checkout = (body: object) =>
    fetch(`${base}/rite/checkout`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });

  // 1. Checkout hands back a session to pay for a known package, and only that.
  assert.equal((await checkout({})).status, 400);
  assert.equal((await checkout({ pack: 'pack1000' })).status, 400);
  const started: any = await checkout({ pack: 'pack7' }).then((r) => r.json());
  assert.equal(started.sessionId, session(1));
  assert.match(started.url, /^https:\/\/checkout\.stripe\.com\//);
  assert.deepEqual(gateway.packs, ['pack7']);
  assert.equal((await checkout({ pack: 'pack3' })).status, 400, 'the 3-rite package is no longer sold');
  const packs: any = await fetch(`${base}/rite/packs`).then((r) => r.json());
  assert.deepEqual(packs.packs, [{ id: 'pack7', rites: 7, amount: 314, currency: 'usd' }]);

  // 2. Webhooks must be signed with the endpoint secret.
  assert.equal((await hook(sessionEvent('checkout.session.completed', session(1)), false)).status, 400);
  const forged = await fetch(`${base}/stripe/webhook`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'stripe-signature': 't=1,v1=deadbeef' },
    body: JSON.stringify(sessionEvent('checkout.session.completed', session(1))),
  });
  assert.equal(forged.status, 400);
  assert.equal((await credit(session(1))).paid, false);

  // 3. Unpaid sessions, other merchants' sessions and unknown packages are not credits.
  await hook(sessionEvent('checkout.session.completed', session(1), { payment_status: 'unpaid' }));
  await hook(sessionEvent('checkout.session.completed', session(1), { metadata: {} }));
  await hook(sessionEvent('checkout.session.completed', session(1), { metadata: { ...RITE_METADATA } }));
  await hook(sessionEvent('checkout.session.completed', session(1), { metadata: { ...RITE_METADATA, pack: 'pack1000' } }));
  assert.equal((await credit(session(1))).paid, false);
  assert.equal((await consecrate(session(1), C1)).status, 402);

  // 4. A signed, paid package session is a credit of seven rites; repeats change nothing.
  for (let i = 0; i < 3; i++) assert.equal((await hook(sessionEvent('checkout.session.completed', session(1)))).status, 200);
  assert.deepEqual(await credit(session(1)), {
    success: true, paid: true, revoked: false, rites: 7, used: 0, remaining: 7, spent: false, burnt: false, signature: null,
  });

  // 5. Each release spends one rite; an eighth intent is refused; asking again
  //    for an intent finds its own burn.
  const burnt = await consecrate(session(1), C1);
  assert.equal(burnt.status, 200);
  assert.equal(burnt.body.joules, J);
  assert.equal(burnt.body.remaining, 6);
  assert.equal((await consecrate(session(1), C1)).body.signature, burnt.body.signature);
  let last = burnt;
  for (let k = 2; k <= 7; k++) {
    last = await consecrate(session(1), C(k));
    assert.equal(last.body.remaining, 7 - k);
  }
  const eighth = await consecrate(session(1), C(8));
  assert.equal(eighth.status, 409);
  assert.equal(eighth.body.exhausted, true);
  const spent = await credit(session(1));
  assert.equal(spent.spent && spent.burnt && spent.used === 7 && spent.remaining === 0, true);
  assert.equal(spent.signature, last.body.signature);
  assert.equal(chain.totalBurnt(), 7 * J);

  // 6. A refund after the burns cannot undo them, and does not error.
  assert.equal((await hook(chargeEvent('charge.refunded', `pi_${session(1)}`))).status, 200);
  assert.equal(chain.totalBurnt(), 7 * J);

  // 7. A refund or dispute before use revokes the credit.
  await hook(sessionEvent('checkout.session.completed', session(2)));
  await hook(chargeEvent('charge.dispute.created', `pi_${session(2)}`));
  assert.equal((await credit(session(2))).revoked, true);
  assert.equal((await consecrate(session(2), C1)).status, 402);
  assert.equal(chain.totalBurnt(), 7 * J);

  // 7b. A refund part-way through a package revokes the rites left.
  await hook(sessionEvent('checkout.session.completed', session(6)));
  assert.equal((await consecrate(session(6), C1)).status, 200);
  await hook(chargeEvent('charge.refunded', `pi_${session(6)}`));
  assert.equal((await consecrate(session(6), C2)).status, 402);
  const refunded = await credit(session(6));
  assert.equal(refunded.revoked && refunded.used === 1 && refunded.remaining === 0, true);
  assert.equal(chain.totalBurnt(), 8 * J);

  // 8. If the webhook is late, Stripe is asked directly.
  gateway.paid.set(session(3), { sessionId: session(3), paymentIntent: 'pi_3', amountTotal: 777, currency: 'usd', rites: 7 });
  assert.equal((await credit(session(3))).paid, true);
  assert.equal((await consecrate(session(4), C1)).status, 402);
  gateway.paid.set(session(4), { sessionId: session(4), paymentIntent: 'pi_4', amountTotal: 777, currency: 'usd', rites: 7 });
  assert.equal((await consecrate(session(4), C1)).status, 200);
  assert.equal(chain.totalBurnt(), 9 * J);

  // 9. Malformed session IDs are refused before anything is looked up.
  assert.equal((await fetch(`${base}/rite/credit/not-a-session`)).status, 400);
  assert.equal((await consecrate('cs_test_short', C1)).status, 402);

  // 10. The sweeper finishes a paid burn nobody came back for, and counts it once.
  await hook(sessionEvent('checkout.session.completed', session(5)));
  chain.dropSends = true;
  const pending = await consecrate(session(5), C2);
  assert.equal(pending.status, 202);
  chain.dropSends = false;
  const pyreBefore: any = await fetch(`${base}/pyre/stats`).then((r) => r.json());
  assert.deepEqual(await sweeper.runOnce(), { checked: 1, confirmed: 1, failed: 0 });
  assert.deepEqual(await sweeper.runOnce(), { checked: 0, confirmed: 0, failed: 0 });
  const pyreAfter: any = await fetch(`${base}/pyre/stats`).then((r) => r.json());
  assert.equal(pyreAfter.stats.totalBurned - pyreBefore.stats.totalBurned, J);
  assert.equal((await credit(session(5))).burnt, true);
  assert.equal(chain.totalBurnt(), 10 * J);
  // 10b. Under a live key, test sessions and test-mode events are refused,
  //      even a test credit already in the ledger; under a test key, live
  //      events are ignored.
  {
    const liveGateway = new FakeStripe(true);
    const liveServer = http
      .createServer(createApp({ rite: { burns, check: null, stripe: { gateway: liveGateway, ledger } } }))
      .listen(0);
    const liveBase = `http://localhost:${(liveServer.address() as any).port}/api/v1`;
    const testCredit = session(7);
    await hook(sessionEvent('checkout.session.completed', testCredit));
    assert.equal((await credit(testCredit)).remaining, 7, 'a test credit with rites left');
    const before = chain.totalBurnt();
    const spend = await fetch(`${liveBase}/rite/consecrate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ platform: 'web', productId: 'stripe-checkout', receiptData: testCredit, commitment: C4 }),
    });
    assert.equal(spend.status, 402);
    assert.equal((await fetch(`${liveBase}/rite/credit/${testCredit}`)).status, 400);
    const liveHook = (event: object) => {
      const payload = JSON.stringify(event);
      return fetch(`${liveBase}/stripe/webhook`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'stripe-signature': stripe.webhooks.generateTestHeaderString({ payload, secret: WHSEC }),
        },
        body: payload,
      });
    };
    const liveSession = `cs_live_${'b'.repeat(20)}1`;
    await liveHook(sessionEvent('checkout.session.completed', liveSession)); // livemode false: ignored
    assert.equal(ledger.getCredit(liveSession), undefined);
    await liveHook({ ...sessionEvent('checkout.session.completed', liveSession), livemode: true });
    assert.equal(ledger.getCredit(liveSession)?.rites, 7);
    // And the test-key server ignores a live event.
    const otherLive = `cs_live_${'c'.repeat(20)}1`;
    await hook({ ...sessionEvent('checkout.session.completed', otherLive), livemode: true });
    assert.equal(ledger.getCredit(otherLive), undefined);
    assert.equal(chain.totalBurnt(), before);
    liveServer.close();
  }

  server.close();

  // 11. Stripe's mode must match the chain: no real money for a devnet burn.
  const saved = { ...config };
  Object.assign(config, {
    stripeSecretKey: 'sk_live_x', stripeWebhookSecret: WHSEC, stripeRitePrices: 'pack7=price_x',
    webOrigin: 'https://ignosis.net', solanaCluster: 'devnet',
  });
  assert.equal(stripeFromConfig(), null);
  Object.assign(config, { stripeSecretKey: 'sk_test_x' });
  assert.notEqual(stripeFromConfig(), null);
  Object.assign(config, { solanaCluster: 'mainnet-beta' });
  assert.equal(stripeFromConfig(), null);
  Object.assign(config, { stripeSecretKey: 'sk_live_x', webOrigin: '' });
  assert.equal(stripeFromConfig(), null);
  Object.assign(config, { webOrigin: 'https://ignosis.net', stripeRitePrices: 'pack1000=price_x' });
  assert.equal(stripeFromConfig(), null, 'no known package has a price');
  Object.assign(config, saved);

  console.log('✅ Stripe: signed webhooks, packages spent one rite per release, refunds revoke unused rites, sweeper finishes paid burns, test and live never mix.');
}

main().catch((e) => {
  console.error('❌ Stripe test failed:', e);
  process.exit(1);
});
