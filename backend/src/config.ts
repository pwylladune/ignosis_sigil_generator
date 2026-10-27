import dotenv from 'dotenv';
dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '3001', 10),
  nodeEnv: process.env.NODE_ENV || 'development',

  // Proxies in front of the app whose X-Forwarded-For entry is trusted: 1 on
  // Fly.io, whose edge appends the client's address. 0 (the default) when the
  // app is reached directly, so a client cannot choose its own address.
  trustProxyHops: parseInt(process.env.TRUST_PROXY_HOPS || '0', 10) || 0,

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

  // Joules burnt per rite: 1618, after phi (1.618...). The physical basis is
  // a 2" x 2" square of 80 gsm paper (25.8 cm2, ~0.21 g at ~16 MJ/kg), which
  // burns to ~3,300 J: the energy of one Solana transaction (~3,290 J).
  riteJoules: 1618,

  // SQLite file for the fulfilment ledger (one burn per rite; a package's
  // rites are counted against its payment).
  // Without it, rites are disabled: idempotency needs persistence.
  riteLedgerPath: process.env.RITE_LEDGER_PATH || '',

  // Web payments (Stripe Checkout). All four are needed, or web payment is off.
  // STRIPE_RITE_PRICES maps each rite package (services/ritePacks.ts) to its
  // Stripe price: `pack3=price_…,pack7=price_…,pack21=price_…`.
  // A live key (sk_live_) is refused unless the cluster is mainnet-beta, and a
  // test key unless it is not: real money never buys a devnet burn.
  stripeSecretKey: process.env.STRIPE_SECRET_KEY || '',
  stripeWebhookSecret: process.env.STRIPE_WEBHOOK_SECRET || '',
  stripeRitePrices: process.env.STRIPE_RITE_PRICES || '',
  webOrigin: (process.env.WEB_ORIGIN || '').replace(/\/+$/, ''),

  // Android rites (Google Play Billing): the service account JSON, from a Google
  // Cloud project linked in Play Console with permission to view and manage
  // orders. Without it, Android rites are refused. Off mainnet only Play test
  // purchases are accepted; on mainnet only real ones.
  googlePlayServiceAccount: process.env.GOOGLE_PLAY_SERVICE_ACCOUNT || '',

  // In-App Purchase Verification Credentials
  appleBundleId: process.env.APPLE_BUNDLE_ID || 'net.ignosis.studio',
  googlePackageName: process.env.GOOGLE_PACKAGE_NAME || 'net.ignosis.studio',
};
