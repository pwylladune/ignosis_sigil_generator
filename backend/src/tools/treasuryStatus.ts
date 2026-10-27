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
}

main().catch((e) => {
  console.error(describeError(e));
  process.exit(1);
});
