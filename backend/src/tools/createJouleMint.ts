/**
 * Creates the IGNOSIS Joule mint (ADR 2026-10-25-ignosis-joule-token):
 * a Token-2022 mint with the NonTransferable extension, 0 decimals and no
 * freeze authority. The whole supply goes to the treasury's own account, then
 * the mint authority is revoked, so the supply can only ever shrink.
 *
 *   npm run build && node dist/tools/createJouleMint.js
 *
 * Environment:
 *   SOLANA_RPC_URL        default https://api.devnet.solana.com
 *   TREASURY_KEYPAIR_PATH default ./treasury.keypair.json (created on devnet
 *                         or a local validator if missing; never on mainnet)
 *
 * Mainnet is refused: a mainnet mint needs a treasury key the owner controls,
 * held in a KMS or HSM, and a deliberate change to this script.
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

/** 10^12 joules: about 618 million rites at 1618 J each. */
const SUPPLY = 1_000_000_000_000n;

const rpcUrl = process.env.SOLANA_RPC_URL || 'https://api.devnet.solana.com';
const isLocal = /localhost|127\.0\.0\.1/.test(rpcUrl);

function loadOrCreateTreasury(): Keypair {
  const file = path.resolve(process.env.TREASURY_KEYPAIR_PATH || 'treasury.keypair.json');
  if (fs.existsSync(file)) {
    return Keypair.fromSecretKey(Uint8Array.from(JSON.parse(fs.readFileSync(file, 'utf8'))));
  }
  const kp = Keypair.generate();
  // Owner-only permissions: this file is a private key.
  fs.writeFileSync(file, JSON.stringify(Array.from(kp.secretKey)), { mode: 0o600 });
  console.log(`Created treasury keypair at ${file}`);
  return kp;
}

async function ensureFunded(connection: Connection, treasury: Keypair) {
  const need = 0.05 * LAMPORTS_PER_SOL;
  if ((await connection.getBalance(treasury.publicKey)) >= need) return;
  console.log('Requesting an airdrop of 1 SOL for fees and rent...');
  const sig = await connection.requestAirdrop(treasury.publicKey, LAMPORTS_PER_SOL);
  const latest = await connection.getLatestBlockhash();
  await connection.confirmTransaction({ signature: sig, ...latest }, 'confirmed');
}

async function main() {
  const connection = new Connection(rpcUrl, 'confirmed');
  const genesis = await connection.getGenesisHash();
  // Mainnet-beta's genesis hash.
  if (genesis === '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d') {
    throw new Error('Refusing to mint on mainnet-beta (see the header comment).');
  }
  if (!isLocal && !rpcUrl.includes('devnet')) {
    throw new Error(`Refusing an RPC that is neither devnet nor local: ${rpcUrl}`);
  }

  const treasury = loadOrCreateTreasury();
  console.log(`Treasury: ${treasury.publicKey.toBase58()}`);
  await ensureFunded(connection, treasury);

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
  console.log(`\nSet in backend/.env:\n  JOULE_MINT_ADDRESS=${mint.publicKey.toBase58()}`);
  console.log(`  TREASURY_PRIVATE_KEY=<contents of the treasury keypair file>`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
