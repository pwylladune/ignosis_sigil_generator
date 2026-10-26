import dotenv from 'dotenv';
dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '3001', 10),
  nodeEnv: process.env.NODE_ENV || 'development',

  // Solana Network Configuration
  solanaRpcUrl: process.env.SOLANA_RPC_URL || 'https://api.devnet.solana.com',
  solanaCluster: (process.env.SOLANA_CLUSTER || 'devnet') as 'devnet' | 'mainnet-beta' | 'localnet',

  // IGNOSIS Joule: a non-transferable Token-2022 mint whose whole supply is
  // held by the treasury and only ever burnt (ADR 2026-10-25-ignosis-joule-token).
  // No default: the old default (7xKXtg…sgAsU) is Samoyed Coin (SAMO), a
  // third-party mainnet token (TASK.md C7).
  jouleMintAddress: process.env.JOULE_MINT_ADDRESS || '',

  // Treasury private key as a JSON byte array. It owns the Joule supply and
  // signs every rite. If absent or invalid, rites are disabled; no keypair is
  // ever generated in its place.
  treasuryPrivateKey: process.env.TREASURY_PRIVATE_KEY || '',

  // Joules burnt per rite: 1618, after phi (1.618...). About the energy of a
  // 1" x 1" square of heavy card (~155 gsm at ~16 MJ/kg), or two squares of
  // 80 gsm paper (~830 J each); one Solana transaction costs ~3,290 J.
  riteJoules: 1618,

  // Store products that buy one rite (comma-separated RITE_PRODUCT_IDS).
  riteProductIds: (process.env.RITE_PRODUCT_IDS || 'net.ignosis.studio.rite')
    .split(',')
    .map((p) => p.trim())
    .filter(Boolean),

  // SQLite file for the fulfilment ledger (one burn per store transaction).
  // Without it, rites are disabled: idempotency needs persistence.
  riteLedgerPath: process.env.RITE_LEDGER_PATH || '',

  // In-App Purchase Verification Credentials
  appleBundleId: process.env.APPLE_BUNDLE_ID || 'net.ignosis.studio',
  googlePackageName: process.env.GOOGLE_PACKAGE_NAME || 'net.ignosis.studio',
};
