import dotenv from 'dotenv';
dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '3001', 10),
  nodeEnv: process.env.NODE_ENV || 'development',

  // Solana Network Configuration
  solanaRpcUrl: process.env.SOLANA_RPC_URL || 'https://api.devnet.solana.com',
  solanaCluster: (process.env.SOLANA_CLUSTER || 'devnet') as 'devnet' | 'mainnet-beta',

  // $IGNOSIS Token Details
  // No default: the previous default (7xKXtg…sgAsU) is Samoyed Coin (SAMO), a
  // third-party mainnet token. There is no $IGNOSIS mint yet (TASK.md C7).
  ignosisMintAddress: process.env.IGNOSIS_MINT_ADDRESS || '',
  ignosisDecimals: parseInt(process.env.IGNOSIS_DECIMALS || '9', 10),

  // Program ID for the Anchor program (none deployed; the placeholder was not valid base58).
  programId: process.env.IGNOSIS_PROGRAM_ID || '',

  // Treasury private key as a JSON byte array. If absent or invalid the
  // treasury is disabled; no keypair is ever generated in its place.
  treasuryPrivateKey: process.env.TREASURY_PRIVATE_KEY || '',

  // In-App Purchase Verification Credentials
  appleBundleId: process.env.APPLE_BUNDLE_ID || 'net.ignosis.studio',
  googlePackageName: process.env.GOOGLE_PACKAGE_NAME || 'net.ignosis.studio',

  // Quantities
  starterPackTokenAmount: 279,
  defaultBurnAmount: 93,
};
