import {
  Connection,
  Keypair,
  LAMPORTS_PER_SOL,
  clusterApiUrl,
} from '@solana/web3.js';
import {
  createMint,
  getOrCreateAssociatedTokenAccount,
  mintTo,
} from '@solana/spl-token';
import * as fs from 'fs';
import * as path from 'path';

async function main() {
  console.log('--- [IGNOSIS] INITIALIZING DEVNET SPL TOKEN MINT ---');

  const connection = new Connection(clusterApiUrl('devnet'), 'confirmed');

  // Check or generate authority keypair
  const keypairPath = path.resolve(process.cwd(), 'deployer-keypair.json');
  let payer: Keypair;

  if (fs.existsSync(keypairPath)) {
    const secretKey = Uint8Array.from(JSON.parse(fs.readFileSync(keypairPath, 'utf8')));
    payer = Keypair.fromSecretKey(secretKey);
    console.log(`Loaded existing deployer keypair: ${payer.publicKey.toBase58()}`);
  } else {
    payer = Keypair.generate();
    // Owner-only permissions: this file is a private key.
    fs.writeFileSync(keypairPath, JSON.stringify(Array.from(payer.secretKey)), { encoding: 'utf8', mode: 0o600 });
    console.log(`Generated fresh deployer keypair: ${payer.publicKey.toBase58()}`);
  }

  // Check balance
  let balance = await connection.getBalance(payer.publicKey);
  console.log(`Current SOL Balance: ${balance / LAMPORTS_PER_SOL} SOL`);

  if (balance < 0.5 * LAMPORTS_PER_SOL) {
    console.log('Requesting 1 SOL Devnet airdrop...');
    try {
      const airdropSig = await connection.requestAirdrop(payer.publicKey, 1 * LAMPORTS_PER_SOL);
      await connection.confirmTransaction(airdropSig);
      balance = await connection.getBalance(payer.publicKey);
      console.log(`Airdrop confirmed. New Balance: ${balance / LAMPORTS_PER_SOL} SOL`);
    } catch (e: any) {
      console.warn(`Airdrop rate limit: ${e.message}. If faucet is throttled, fund from faucet.solana.com`);
    }
  }

  // 1. Create $IGNOSIS Mint (9 Decimals)
  console.log('Creating SPL Token Mint...');
  const mint = await createMint(
    connection,
    payer,
    payer.publicKey, // mint authority
    null, // no freeze authority: holders' accounts can never be frozen
    9               // 9 decimals (same as SOL / standard SPL)
  );
  console.log(`🔥 $IGNOSIS MINT CREATED: ${mint.toBase58()}`);

  // 2. Create Associated Token Account for Treasury
  console.log('Creating Treasury Associated Token Account...');
  const treasuryAta = await getOrCreateAssociatedTokenAccount(
    connection,
    payer,
    mint,
    payer.publicKey
  );
  console.log(`Treasury ATA: ${treasuryAta.address.toBase58()}`);

  // 3. Mint 100,000,000 $IGNOSIS to Treasury
  const supply = BigInt(100_000_000) * BigInt(10 ** 9);
  console.log('Minting 100,000,000 $IGNOSIS into Treasury Vault...');
  const mintTx = await mintTo(
    connection,
    payer,
    mint,
    treasuryAta.address,
    payer,
    supply
  );
  console.log(`Tokens Minted! Tx: ${mintTx}`);

  // Output config snippet
  console.log('\n=============================================');
  console.log('SUCCESS! Add these to your backend/.env:');
  console.log(`IGNOSIS_MINT_ADDRESS=${mint.toBase58()}`);
  // The secret key is never printed (scrollback and CI logs keep it); copy it
  // from the 0600 keypair file into your secret store instead.
  console.log(`TREASURY_PRIVATE_KEY=<contents of ${keypairPath}>`);
  console.log('=============================================\n');
}

main().catch(console.error);
