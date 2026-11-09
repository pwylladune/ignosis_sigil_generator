/**
 * Read-only: where the treasury stands. Needs no key, so it can run anywhere.
 *
 *   npm run build && node dist/tools/treasuryStatus.js
 *
 * Environment:
 *   SOLANA_RPC_URL      default https://api.devnet.solana.com
 *   JOULE_MINT_ADDRESS  the Joule mint
 *   TREASURY_OWNER      the owner's public key
 *   RITE_DELEGATE       the server's public key
 *
 * Prints the supply, the owner's Joules, the server's allowance in rites, and
 * how many burns the server's SOL can still pay for.
 *
 * With --check it exits 1 when the server could soon stop burning: the
 * delegate is not the server key, the allowance is under LOW_ALLOWANCE_RITES,
 * or the SOL pays for fewer than MIN_FEE_BURNS burns (default 2000, about
 * 0.01 SOL). A scheduled job runs it so a failure reaches the owner by email.
 */
import { Connection, LAMPORTS_PER_SOL, PublicKey } from '@solana/web3.js';
import { getAccount, getAssociatedTokenAddressSync, getMint } from '@solana/spl-token';
import { config } from '../config.js';
import { JOULE_PROGRAM_ID, jouleMintProblem } from '../services/joule.js';
import { LOW_ALLOWANCE_RITES } from '../services/riteBurn.js';
import { describeError } from './treasuryKeys.js';

/** A burn's base fee, in lamports (one signature). */
const FEE_LAMPORTS = 5000;

async function main() {
  const rpcUrl = process.env.SOLANA_RPC_URL || 'https://api.devnet.solana.com';
  const connection = new Connection(rpcUrl, 'confirmed');
  const mint = new PublicKey(process.env.JOULE_MINT_ADDRESS || '');
  const owner = new PublicKey(process.env.TREASURY_OWNER || '');
  const delegate = new PublicKey(process.env.RITE_DELEGATE || '');

  const info = await getMint(connection, mint, 'confirmed', JOULE_PROGRAM_ID);
  const account = await getAccount(
    connection,
    getAssociatedTokenAddressSync(mint, owner, false, JOULE_PROGRAM_ID),
    'confirmed',
    JOULE_PROGRAM_ID
  );
  const allowed = account.delegate?.equals(delegate) ? account.delegatedAmount : 0n;
  const rites = allowed / BigInt(config.riteJoules);
  const lamports = await connection.getBalance(delegate);

  console.log(`Mint:       ${mint.toBase58()} (${jouleMintProblem(info) ?? 'a proper Joule mint'})`);
  console.log(`Supply:     ${info.supply} J`);
  console.log(`Owner:      ${owner.toBase58()} holds ${account.amount} J`);
  console.log(`Delegate:   ${account.delegate?.toBase58() ?? 'none'}${account.delegate && !account.delegate.equals(delegate) ? ' (NOT the server key)' : ''}`);
  console.log(`Allowance:  ${allowed} J = ${rites} rites${rites < LOW_ALLOWANCE_RITES ? '  <- low: approve more' : ''}`);
  console.log(`Server SOL: ${lamports / LAMPORTS_PER_SOL} SOL, about ${Math.floor(lamports / FEE_LAMPORTS)} burns of fees`);

  if (!process.argv.includes('--check')) return;
  const problems = treasuryProblems({
    delegateIsServer: !!account.delegate?.equals(delegate),
    rites,
    feeBurns: Math.floor(lamports / FEE_LAMPORTS),
    minFeeBurns: Number(process.env.MIN_FEE_BURNS || 2000),
  });
  for (const p of problems) console.error(`PROBLEM: ${p}`);
  if (problems.length > 0) process.exit(1);
  console.log('OK: the server can keep burning.');
}

/** Why the server could soon stop burning; empty when all is well. */
export function treasuryProblems(s: {
  delegateIsServer: boolean;
  rites: bigint;
  feeBurns: number;
  minFeeBurns: number;
}): string[] {
  const problems: string[] = [];
  if (!s.delegateIsServer) problems.push('the server key is not the delegate of the treasury account: no rite can burn');
  else if (s.rites < BigInt(LOW_ALLOWANCE_RITES)) {
    problems.push(`the allowance covers ${s.rites} rites (under ${LOW_ALLOWANCE_RITES}): approve more from the cold owner`);
  }
  if (s.feeBurns < s.minFeeBurns) {
    problems.push(`the server's SOL pays for ${s.feeBurns} burns (under ${s.minFeeBurns}): send it SOL`);
  }
  return problems;
}

if (process.argv[1]?.endsWith('/treasuryStatus.js')) {
  main().catch((e) => {
    console.error(describeError(e));
    process.exit(1);
  });
}
