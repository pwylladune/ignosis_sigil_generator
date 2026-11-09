process.env.NODE_ENV = 'test';
/**
 * The counterexamples TLC finds in formal/RiteBurn.tla (Fixed = FALSE), as
 * tests: a retry must never build a second burn while the first can still
 * land, and must look for the first only after it no longer can.
 */
import assert from 'node:assert/strict';
import { config } from './config.js';
import { RiteBurnService, isAlreadyProcessed } from './services/riteBurn.js';
import { riteMemo } from './services/joule.js';
import { RiteLedger } from './services/riteLedger.js';
import { FakeChain } from './test-support.js';

const J = config.riteJoules;
const C1 = '1'.repeat(64);
const C2 = '2'.repeat(64);
const C3 = '3'.repeat(64);

function setup() {
  const chain = new FakeChain();
  const ledger = new RiteLedger(':memory:');
  const burns = new RiteBurnService(chain, ledger, { joules: J, pollMs: 2, timeoutMs: 30 });
  return { chain, ledger, burns };
}

async function main() {
  // 1. The burn lands between the retry's two reads (status, then height),
  //    and the height read comes back past its last valid block.
  {
    const { chain, ledger, burns } = setup();
    chain.holdSends = true;
    assert.equal((await burns.fulfil('p1', C1)).status, 'pending');
    const first = ledger.get('p1')!.signature;
    chain.afterStatus = () => {
      chain.land(first); // Lands while it still can...
      chain.height += 200; // ...and then its blockhash expires.
    };
    chain.holdSends = false;
    const out = await burns.fulfil('p1', C1);
    assert.equal(chain.burns.get(riteMemo(C1)), J, 'one rite, one burn');
    assert.equal(chain.prepared, 1, 'no second burn was built');
    assert.deepEqual([out.status, (out as any).signature], ['confirmed', first]);
  }

  // 2. A send refused at preflight is not proof that nothing will burn: the
  //    burn was in flight and lands after the refusal. The retry must not
  //    rebuild while it can still land.
  {
    const { chain, ledger, burns } = setup();
    chain.holdSends = chain.rejectSends = true;
    assert.equal((await burns.fulfil('p2', C2)).status, 'failed');
    const first = ledger.get('p2')!.signature;
    chain.holdSends = chain.rejectSends = false;
    chain.afterStatus = () => chain.land(first);
    await burns.fulfil('p2', C2);
    const out = await burns.fulfil('p2', C2);
    assert.equal(chain.burns.get(riteMemo(C2)), J, 'one rite, one burn');
    assert.equal(chain.prepared, 1, 'no second burn was built');
    assert.deepEqual([out.status, (out as any).signature], ['confirmed', first]);
  }

  // 3. A refused burn that never lands is rebuilt, but only once it has expired.
  {
    const { chain, ledger, burns } = setup();
    chain.holdSends = chain.rejectSends = true;
    assert.equal((await burns.fulfil('p3', C3)).status, 'failed');
    const first = ledger.get('p3')!.signature;
    assert.equal((await burns.fulfil('p3', C3)).status, 'failed');
    assert.equal(chain.prepared, 1, 'still the same burn while it could land');
    chain.holdSends = chain.rejectSends = false;
    chain.height += 200;
    const out = await burns.fulfil('p3', C3);
    assert.equal(out.status, 'confirmed');
    assert.notEqual((out as any).signature, first);
    assert.equal(chain.burns.get(riteMemo(C3)), J);
    assert.equal(chain.prepared, 2);
  }

  // 4. "Already processed" from the RPC means the burn landed: not a refusal.
  assert.ok(isAlreadyProcessed('Transaction simulation failed: This transaction has already been processed'));
  assert.ok(isAlreadyProcessed('AlreadyProcessed'));
  assert.ok(!isAlreadyProcessed('Transaction simulation failed: Error processing Instruction 0: custom program error: 0x1'));
  assert.ok(!isAlreadyProcessed('Blockhash not found'));

  console.log('✅ Burn retries: nothing is rebuilt while the first burn can land (TLC counterexamples).');
}

main().catch((e) => {
  console.error('❌ Burn race test failed:', e);
  process.exit(1);
});
