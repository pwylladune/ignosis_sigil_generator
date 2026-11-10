process.env.NODE_ENV = 'test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { config } from './config.js';
import { createApp } from './server.js';
import { MachineGuard, machineGuardFromEnv, parseFlyMachines } from './services/machineGuard.js';
import { RiteBurnService } from './services/riteBurn.js';
import { RiteLedger } from './services/riteLedger.js';
import { PaidSession, StripeGateway } from './services/stripeRite.js';
import { FakeChain } from './test-support.js';

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ignosis-hardening-'));
const C1 = 'a'.repeat(64);
const SESSION = `cs_test_${'s'.repeat(24)}`;
const PAID: PaidSession = { sessionId: SESSION, paymentIntent: 'pi_1', amountTotal: 314, currency: 'usd', rites: 7 };

class CountingStripe implements StripeGateway {
  readonly live = false;
  checkouts = 0;
  lookups = 0;
  async createCheckout() {
    this.checkouts++;
    return { id: SESSION, url: 'https://checkout.stripe.com/c/pay/x' };
  }
  async offers() {
    return [];
  }
  async retrievePaid(sessionId: string) {
    this.lookups++;
    return sessionId === SESSION ? PAID : null;
  }
  parseWebhook(): never {
    throw new Error('unused');
  }
}

async function listen(app: ReturnType<typeof createApp>) {
  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, resolve));
  return { server, base: `http://localhost:${(server.address() as any).port}/api/v1/rite` };
}

const post = (url: string, body: object) =>
  fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });

const web = { platform: 'web', productId: 'pack7', receiptData: SESSION, commitment: C1 };

async function main() {
  // 1. Fly's DNS answer is read as machine IDs; the guard is off anywhere else.
  {
    assert.deepEqual(parseFlyMachines([['815744a9529338 sjc']]), ['815744a9529338']);
    assert.deepEqual(parseFlyMachines([['815744a9529338 sjc,d8d9945b0e2948 ord']]), ['815744a9529338', 'd8d9945b0e2948']);
    // A long answer arrives in chunks, and may arrive as several records.
    assert.deepEqual(parseFlyMachines([['aaa sjc,bb', 'b ord'], ['ccc iad']]), ['aaa', 'bbb', 'ccc']);
    assert.deepEqual(parseFlyMachines([]), []);
    assert.equal(machineGuardFromEnv({}), null);
    assert.ok(machineGuardFromEnv({ FLY_APP_NAME: 'app', FLY_MACHINE_ID: 'aaa' }));
    console.log('1. Machines: the DNS answer parses; no guard off Fly.');
  }

  // 2. A second machine turns the guard off; a failed lookup changes nothing.
  {
    let answer: string[] | Error = ['me'];
    const guard = new MachineGuard(async () => {
      if (answer instanceof Error) throw answer;
      return answer;
    }, 'me');
    const saved = { error: console.error, log: console.log };
    console.error = () => {};
    console.log = () => {};
    assert.ok(guard.alone, 'alone before the first answer');
    await guard.check();
    assert.ok(guard.alone);
    answer = ['me', 'other'];
    await guard.check();
    assert.equal(guard.alone, false);
    answer = new Error('SERVFAIL');
    await guard.check();
    assert.equal(guard.alone, false, 'a failed lookup keeps the last answer');
    answer = ['me'];
    await guard.check();
    assert.ok(guard.alone);
    answer = new Error('SERVFAIL');
    await guard.check();
    assert.ok(guard.alone, 'a failed lookup is not a second machine');
    // An answer without this machine (it has just started) is still a second machine.
    answer = ['other'];
    await guard.check();
    assert.equal(guard.alone, false);
    console.error = saved.error;
    console.log = saved.log;
    console.log('2. Guard: off with a second machine, unchanged by a failed lookup, back on alone.');
  }

  // 3. While another machine runs, nothing is burnt and nothing is sold.
  {
    const ledger = new RiteLedger(path.join(dir, 'guard.sqlite'));
    const chain = new FakeChain();
    const burns = new RiteBurnService(chain, ledger, { joules: config.riteJoules });
    const stripe = new CountingStripe();
    let ids = ['me', 'other'];
    const machines = new MachineGuard(async () => ids, 'me');
    const saved = { error: console.error, log: console.log };
    console.error = () => {};
    console.log = () => {};
    await machines.check();
    const { server, base } = await listen(createApp({ rite: { burns, check: null, ledger, stripe: { gateway: stripe, ledger }, machines } }));

    assert.equal((await post(`${base}/consecrate`, web)).status, 503);
    assert.equal((await post(`${base}/checkout`, { pack: 'pack7' })).status, 503);
    assert.equal(chain.totalBurnt(), 0);
    assert.equal(stripe.checkouts, 0);
    assert.equal(ledger.ritesSpent(`web:${SESSION}`), 0, 'no rite was taken from the package');

    ids = ['me'];
    await machines.check();
    console.error = saved.error;
    console.log = saved.log;
    const ok = await post(`${base}/consecrate`, web);
    assert.equal(ok.status, 200);
    assert.equal(chain.totalBurnt(), config.riteJoules);
    assert.equal((await post(`${base}/checkout`, { pack: 'pack7' })).status, 200);
    server.close();
    ledger.close();
    console.log('3. Second machine: no burn and no checkout until it is gone.');
  }

  // 4. Each route has its own limit, and a refusal costs the store nothing.
  {
    const ledger = new RiteLedger(path.join(dir, 'limits.sqlite'));
    const burns = new RiteBurnService(new FakeChain(), ledger, { joules: config.riteJoules });
    const stripe = new CountingStripe();
    let checks = 0;
    const check = async () => {
      checks++;
      return { valid: false as const, reason: 'not a rite' };
    };
    const limits = { consecrate: 3, checkout: 2, credit: 4, check: 2 };
    const { server, base } = await listen(createApp({ rite: { burns, check, ledger, stripe: { gateway: stripe, ledger } }, limits }));

    const statuses = async (n: number, call: () => Promise<Response>) => {
      const out: number[] = [];
      for (let i = 0; i < n; i++) out.push((await call()).status);
      return out;
    };

    assert.deepEqual(await statuses(3, () => post(`${base}/checkout`, { pack: 'pack7' })), [200, 200, 429]);
    assert.equal(stripe.checkouts, 2);

    const unknown = `cs_test_${'u'.repeat(24)}`;
    assert.deepEqual(await statuses(5, () => fetch(`${base}/credit/${unknown}`)), [200, 200, 200, 200, 429]);
    assert.equal(stripe.lookups, 4);

    const sig = '4'.repeat(88);
    assert.deepEqual(await statuses(3, () => fetch(`${base}/${sig}`)), [404, 404, 429]);
    assert.equal(checks, 2);

    // Checkout being limited does not stop a payer releasing.
    const released = await statuses(4, () => post(`${base}/consecrate`, web));
    assert.deepEqual(released, [200, 200, 200, 429]);
    const refused: any = await post(`${base}/consecrate`, web).then((r) => r.json());
    assert.equal(refused.success, false);
    assert.match(refused.error, /Too many requests/);
    server.close();
    ledger.close();
    console.log('4. Limits: checkout, credit, check and consecrate are each limited on their own, in JSON.');
  }

  fs.rmSync(dir, { recursive: true, force: true });
  console.log('✅ Hardening: one machine or no rites, and per-route limits before any store or chain call.');
}

main().catch((e) => {
  console.error('❌ Hardening test failed:', e);
  process.exit(1);
});
