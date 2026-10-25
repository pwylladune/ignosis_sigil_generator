import dotenv from 'dotenv';
dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '3001', 10),
  nodeEnv: process.env.NODE_ENV || 'development',

  // Solana Network Configuration
  solanaRpcUrl: process.env.SOLANA_RPC_URL || 'https://api.devnet.solana.com',
  solanaCluster: (process.env.SOLANA_CLUSTER || 'devnet') as 'devnet' | 'mainnet-beta',

  // $IGNOSIS Token Details
  ignosisMintAddress: process.env.IGNOSIS_MINT_ADDRESS || '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',
  ignosisDecimals: parseInt(process.env.IGNOSIS_DECIMALS || '9', 10),

  // Program ID for Anchor Consecration Incinerator
  programId: process.env.IGNOSIS_PROGRAM_ID || 'Ignos1s111111111111111111111111111111111111',

  // Treasury Private Key (JSON array string or base58 string).
  // If not provided in development, a simulated test keypair is generated.
  treasuryPrivateKey: process.env.TREASURY_PRIVATE_KEY || '',

  // In-App Purchase Verification Credentials
  appleBundleId: process.env.APPLE_BUNDLE_ID || 'com.ignosis.sigilgenerator',
  googlePackageName: process.env.GOOGLE_PACKAGE_NAME || 'com.ignosis.sigilgenerator',

  // Quantities
  starterPackTokenAmount: 279,
  defaultBurnAmount: 93,
};
