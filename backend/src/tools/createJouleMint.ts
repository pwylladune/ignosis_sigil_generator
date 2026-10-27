/**
 * Creates the IGNOSIS Joule mint (ADR 2026-10-25-ignosis-joule-token):
 * a Token-2022 mint with the NonTransferable extension, 0 decimals and no
 * freeze authority. The whole supply goes to the owner's own account, then
 * the mint authority is revoked, so the supply can only ever shrink.
 *
 *   npm run build && node dist/tools/createJouleMint.js [--mainnet]
 *
 * Environment:
 *   SOLANA_RPC_URL        default https://api.devnet.solana.com
 *   TREASURY_KEYPAIR_PATH the owner's keypair, default ./treasury.keypair.json.
 *                         Created if missing on devnet or a local validator.
 *                         On mainnet it must already exist: it is the cold key
 *                         the owner holds offline (ADR 2026-10-27-ignosis-
 *                         treasury-cold-owner-hot-delegate), and it pays the
 *                         rent (about 0.01 SOL).
 *
 * Mainnet needs `--mainnet` on the command line. Afterwards the owner approves
 * the server's key as delegate with approveRiteDelegate.
 */
import * as fs from 'fs';
import * as path from 'path';
import {
  Connection,
  Keypair,
  LAMPORTS_PER_SOL,
  SystemProgram,
  Transaction,
  sendAndConfirmTransaction,
} from '@solana/web3.js';
import {
  AuthorityType,
  ExtensionType,
  createAssociatedTokenAccountIdempotentInstruction,
  createInitializeMetadataPointerInstruction,
  createInitializeMintInstruction,
  createInitializeNonTransferableMintInstruction,
  createMintToCheckedInstruction,
  createSetAuthorityInstruction,
  getAssociatedTokenAddressSync,
  getMint,
  getMintLen,
  tokenMetadataInitializeWithRentTransfer,
} from '@solana/spl-token';
import { JOULE_DECIMALS, JOULE_PROGRAM_ID, jouleMintProblem } from '../services/joule.js';
import { Cluster, checkedCluster, readKeypair } from './treasuryKeys.js';

/** 10^12 joules: about 618 million rites at 1618 J each. */
const SUPPLY = 1_000_000_000_000n;

const rpcUrl = process.env.SOLANA_RPC_URL || 'https://api.devnet.solana.com';

function loadOrCreateTreasury(cluster: Cluster): Keypair {
  const file = path.resolve(process.env.TREASURY_KEYPAIR_PATH || 'treasury.keypair.json');
  // A mainnet owner key is made and kept offline by its owner, never here.
  if (fs.existsSync(file) || cluster === 'mainnet-beta') return readKeypair(file);
  const kp = Keypair.generate();
  // Owner-only permissions: this file is a private key.
  fs.writeFileSync(file, JSON.stringify(Array.from(kp.secretKey)), { mode: 0o600 });
  console.log(`Created treasury keypair at ${file}`);
  return kp;
}

async function ensureFunded(connection: Connection, treasury: Keypair, cluster: Cluster) {
  const need = 0.05 * LAMPORTS_PER_SOL;
  if ((await connection.getBalance(treasury.publicKey)) >= need) return;
  if (cluster === 'mainnet-beta') {
    throw new Error(`Fund the owner ${treasury.publicKey.toBase58()} with at least 0.05 SOL first (rent and fees).`);
  }
  console.log('Requesting an airdrop of 1 SOL for fees and rent...');
  const sig = await connection.requestAirdrop(treasury.publicKey, LAMPORTS_PER_SOL);
  const latest = await connection.getLatestBlockhash();
  await connection.confirmTransaction({ signature: sig, ...latest }, 'confirmed');
}

async function main() {
  const connection = new Connection(rpcUrl, 'confirmed');
  const cluster = await checkedCluster(connection, rpcUrl);

  const treasury = loadOrCreateTreasury(cluster);
  console.log(`Cluster:  ${cluster}`);
  console.log(`Owner:    ${treasury.publicKey.toBase58()}`);
  await ensureFunded(connection, treasury, cluster);

  const mint = Keypair.generate();
  const mintLen = getMintLen([ExtensionType.NonTransferable, ExtensionType.MetadataPointer]);
  const rent = await connection.getMinimumBalanceForRentExemption(mintLen);

  // 1. The mint: metadata stored on the mint itself, non-transferable, no freeze authority.
  await sendAndConfirmTransaction(
    connection,
    new Transaction().add(
      SystemProgram.createAccount({
        fromPubkey: treasury.publicKey,
        newAccountPubkey: mint.publicKey,
        space: mintLen,
        lamports: rent,
        programId: JOULE_PROGRAM_ID,
      }),
      createInitializeMetadataPointerInstruction(mint.publicKey, treasury.publicKey, mint.publicKey, JOULE_PROGRAM_ID),
      createInitializeNonTransferableMintInstruction(mint.publicKey, JOULE_PROGRAM_ID),
      createInitializeMintInstruction(mint.publicKey, JOULE_DECIMALS, treasury.publicKey, null, JOULE_PROGRAM_ID)
    ),
    [treasury, mint]
  );

  // 2. Name and symbol, so explorers show what the token is.
  await tokenMetadataInitializeWithRentTransfer(
    connection,
    treasury,
    mint.publicKey,
    treasury.publicKey,
    treasury,
    'IGNOSIS Joule',
    'JOULE',
    '',
    [],
    { commitment: 'confirmed' },
    JOULE_PROGRAM_ID
  );

  // 3. The whole supply to the treasury's account, then no more minting, ever.
  const treasuryAta = getAssociatedTokenAddressSync(mint.publicKey, treasury.publicKey, false, JOULE_PROGRAM_ID);
  const sig = await sendAndConfirmTransaction(
    connection,
    new Transaction().add(
      createAssociatedTokenAccountIdempotentInstruction(
        treasury.publicKey,
        treasuryAta,
        treasury.publicKey,
        mint.publicKey,
        JOULE_PROGRAM_ID
      ),
      createMintToCheckedInstruction(
        mint.publicKey,
        treasuryAta,
        treasury.publicKey,
        SUPPLY,
        JOULE_DECIMALS,
        [],
        JOULE_PROGRAM_ID
      ),
      createSetAuthorityInstruction(mint.publicKey, treasury.publicKey, AuthorityType.MintTokens, null, [], JOULE_PROGRAM_ID)
    ),
    [treasury]
  );

  const info = await getMint(connection, mint.publicKey, 'confirmed', JOULE_PROGRAM_ID);
  const problem = jouleMintProblem(info);
  if (problem) throw new Error(`The new mint failed its own check: ${problem}`);

  console.log(`\nJoule mint:    ${mint.publicKey.toBase58()}`);
  console.log(`Supply:        ${info.supply} J in ${treasuryAta.toBase58()}`);
  console.log(`Mint revoked:  ${sig}`);
  console.log(`\nSet on the server:\n  JOULE_MINT_ADDRESS=${mint.publicKey.toBase58()}`);
  if (cluster === 'mainnet-beta') {
    console.log(`  TREASURY_OWNER=${treasury.publicKey.toBase58()}`);
    console.log(`  TREASURY_PRIVATE_KEY=<the server's own key, never this one>`);
    console.log(`Then approve the server's key with approveRiteDelegate --mainnet.`);
  } else {
    console.log(`  TREASURY_PRIVATE_KEY=<contents of the treasury keypair file>`);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
