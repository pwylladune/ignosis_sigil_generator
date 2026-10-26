process.env.NODE_ENV = 'test';
import assert from 'node:assert/strict';
import http from 'http';
import Stripe from 'stripe';
import { config } from './config.js';
import { createApp, stripeFromConfig } from './server.js';
import { RiteBurnService } from './services/riteBurn.js';
import { RiteLedger } from './services/riteLedger.js';
import { RiteSweeper } from './services/riteSweeper.js';
import { PaidSession, RITE_METADATA, StripeGateway } from './services/stripeRite.js';
import { FakeChain } from './test-support.js';

const J = config.riteJoules;
const C1 = 'c'.repeat(64);
const C2 = 'd'.repeat(64);
const WHSEC = 'whsec_test_ignosis';
const stripe = new Stripe('sk_test_offline');
const session = (n: number) => `cs_test_${'a'.repeat(20)}${n}`;

/** Stripe's Checkout and lookup are faked; webhook signatures are verified for real. */
class FakeStripe implements StripeGateway {
  created = 0;
  /** Sessions Stripe would report as paid if asked directly. */
  paid = new Map<string, PaidSession>();
  async createCheckout() {
    const id = session(++this.created);
    return { id, url: `https://checkout.stripe.com/c/pay/${id}` };
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
        metadata: RITE_METADATA,
        ...overrides,
      },
    },
  };
}

const chargeEvent = (type: string, paymentIntent: string) => ({
  id: `evt_${Math.random().toString(36).slice(2)}`,
  object: 'event',
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

  // 1. Checkout hands back a session to pay.
  const started: any = await fetch(`${base}/rite/checkout`, { method: 'POST' }).then((r) => r.json());
  assert.equal(started.sessionId, session(1));
  assert.match(started.url, /^https:\/\/checkout\.stripe\.com\//);

  // 2. Webhooks must be signed with the endpoint secret.
  assert.equal((await hook(sessionEvent('checkout.session.completed', session(1)), false)).status, 400);
  const forged = await fetch(`${base}/stripe/webhook`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'stripe-signature': 't=1,v1=deadbeef' },
    body: JSON.stringify(sessionEvent('checkout.session.completed', session(1))),
  });
  assert.equal(forged.status, 400);
  assert.equal((await credit(session(1))).paid, false);

  // 3. Unpaid sessions and other merchants' sessions are not credits.
  await hook(sessionEvent('checkout.session.completed', session(1), { payment_status: 'unpaid' }));
  await hook(sessionEvent('checkout.session.completed', session(1), { metadata: {} }));
  assert.equal((await credit(session(1))).paid, false);
  assert.equal((await consecrate(session(1), C1)).status, 402);

  // 4. A signed, paid rite session is a credit; repeats change nothing.
  for (let i = 0; i < 3; i++) assert.equal((await hook(sessionEvent('checkout.session.completed', session(1)))).status, 200);
  assert.deepEqual(await credit(session(1)), {
    success: true, paid: true, revoked: false, spent: false, burnt: false, signature: null,
  });

  // 5. Spending the credit burns once; the credit cannot buy a second intent.
  const burnt = await consecrate(session(1), C1);
  assert.equal(burnt.status, 200);
  assert.equal(burnt.body.joules, J);
  assert.equal((await consecrate(session(1), C2)).status, 409);
  assert.equal((await consecrate(session(1), C1)).body.signature, burnt.body.signature);
  const spent = await credit(session(1));
  assert.equal(spent.spent && spent.burnt && spent.signature === burnt.body.signature, true);
  assert.equal(chain.totalBurnt(), J);

  // 6. A refund after the burn cannot undo it, and does not error.
  assert.equal((await hook(chargeEvent('charge.refunded', `pi_${session(1)}`))).status, 200);
  assert.equal((await credit(session(1))).revoked, false);

  // 7. A refund or dispute before use revokes the credit.
  await hook(sessionEvent('checkout.session.completed', session(2)));
  await hook(chargeEvent('charge.dispute.created', `pi_${session(2)}`));
  assert.equal((await credit(session(2))).revoked, true);
  assert.equal((await consecrate(session(2), C1)).status, 402);
  assert.equal(chain.totalBurnt(), J);

  // 8. If the webhook is late, Stripe is asked directly.
  gateway.paid.set(session(3), { sessionId: session(3), paymentIntent: 'pi_3', amountTotal: 777, currency: 'usd' });
  assert.equal((await credit(session(3))).paid, true);
  assert.equal((await consecrate(session(4), C1)).status, 402);
  gateway.paid.set(session(4), { sessionId: session(4), paymentIntent: 'pi_4', amountTotal: 777, currency: 'usd' });
  assert.equal((await consecrate(session(4), C1)).status, 200);
  assert.equal(chain.totalBurnt(), 2 * J);

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
  assert.equal(chain.totalBurnt(), 3 * J);
  server.close();

  // 11. Stripe's mode must match the chain: no real money for a devnet burn.
  const saved = { ...config };
  Object.assign(config, {
    stripeSecretKey: 'sk_live_x', stripeWebhookSecret: WHSEC, stripeRitePriceId: 'price_x',
    webOrigin: 'https://ignosis.net', solanaCluster: 'devnet',
  });
  assert.equal(stripeFromConfig(), null);
  Object.assign(config, { stripeSecretKey: 'sk_test_x' });
  assert.notEqual(stripeFromConfig(), null);
  Object.assign(config, { solanaCluster: 'mainnet-beta' });
  assert.equal(stripeFromConfig(), null);
  Object.assign(config, { stripeSecretKey: 'sk_live_x', webOrigin: '' });
  assert.equal(stripeFromConfig(), null);
  Object.assign(config, saved);

  console.log('✅ Stripe: signed webhooks, credits spent once, refunds revoke unused credits, sweeper finishes paid burns.');
}

main().catch((e) => {
  console.error('❌ Stripe test failed:', e);
  process.exit(1);
});
