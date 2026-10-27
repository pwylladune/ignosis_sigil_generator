/**
 * The owner approves the server's key to burn a number of rites from the
 * Joule account (ADR 2026-10-27-ignosis-treasury-cold-owner-hot-delegate).
 * Run on the owner's machine with the cold key; the server never sees it.
 *
 *   npm run build && node dist/tools/approveRiteDelegate.js [--mainnet] [--revoke]
 *
 * Environment:
 *   SOLANA_RPC_URL        default https://api.devnet.solana.com
 *   TREASURY_KEYPAIR_PATH the owner's (cold) keypair file
 *   JOULE_MINT_ADDRESS    the Joule mint
 *   RITE_DELEGATE         the server's public key (from TREASURY_PRIVATE_KEY)
 *   RITES                 rites to allow, default 1000 (1618 J each)
 *
 * Approval sets the allowance; it does not add to it. `--revoke` removes the
 * delegate, so the server can burn nothing until the owner approves again.
 */
import { Connection, PublicKey, Transaction, sendAndConfirmTransaction } from '@solana/web3.js';
import {
  createApproveCheckedInstruction,
  createRevokeInstruction,
  getAccount,
  getAssociatedTokenAddressSync,
  getMint,
} from '@solana/spl-token';
import { config } from '../config.js';
import { JOULE_DECIMALS, JOULE_PROGRAM_ID, jouleMintProblem } from '../services/joule.js';
import { checkedCluster, readKeypair } from './treasuryKeys.js';

async function main() {
  const rpcUrl = process.env.SOLANA_RPC_URL || 'https://api.devnet.solana.com';
  const connection = new Connection(rpcUrl, 'confirmed');
  const cluster = await checkedCluster(connection, rpcUrl);
  const owner = readKeypair(process.env.TREASURY_KEYPAIR_PATH || 'treasury.keypair.json');
  const mint = new PublicKey(process.env.JOULE_MINT_ADDRESS || '');
  const revoke = process.argv.includes('--revoke');

  const problem = jouleMintProblem(await getMint(connection, mint, 'confirmed', JOULE_PROGRAM_ID));
  if (problem) throw new Error(`Not a Joule mint: ${problem}`);
  const account = getAssociatedTokenAddressSync(mint, owner.publicKey, false, JOULE_PROGRAM_ID);
  const before = await getAccount(connection, account, 'confirmed', JOULE_PROGRAM_ID);
  console.log(`Cluster:  ${cluster}`);
  console.log(`Owner:    ${owner.publicKey.toBase58()} (${before.amount} J)`);
  console.log(`Before:   delegate ${before.delegate?.toBase58() ?? 'none'}, ${before.delegatedAmount} J`);

  let ix;
  if (revoke) {
    ix = createRevokeInstruction(account, owner.publicKey, [], JOULE_PROGRAM_ID);
  } else {
    const delegate = new PublicKey(process.env.RITE_DELEGATE || '');
    if (delegate.equals(owner.publicKey)) throw new Error('RITE_DELEGATE must be the server key, not the owner');
    const rites = BigInt(process.env.RITES || '1000');
    if (rites <= 0n) throw new Error('RITES must be positive');
    const joules = rites * BigInt(config.riteJoules);
    if (joules > before.amount) throw new Error(`The account holds only ${before.amount} J`);
    ix = createApproveCheckedInstruction(account, mint, delegate, owner.publicKey, joules, JOULE_DECIMALS, [], JOULE_PROGRAM_ID);
  }
  const sig = await sendAndConfirmTransaction(connection, new Transaction().add(ix), [owner], { commitment: 'confirmed' });

  const after = await getAccount(connection, account, 'confirmed', JOULE_PROGRAM_ID);
  const rites = after.delegatedAmount / BigInt(config.riteJoules);
  console.log(`After:    delegate ${after.delegate?.toBase58() ?? 'none'}, ${after.delegatedAmount} J (${rites} rites)`);
  console.log(`Signature: ${sig}`);
}

main().catch((e) => {
  console.error(e.message ?? e);
  process.exit(1);
});
