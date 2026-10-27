import express, { NextFunction, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { config } from './config.js';
import { Connection, Keypair, PublicKey } from '@solana/web3.js';
import { ReceiptValidatorService } from './services/receiptValidator.js';
import { PyreIndexerService } from './services/pyreIndexer.js';
import { RiteBurnService, SolanaRiteChain } from './services/riteBurn.js';
import { RiteLedger } from './services/riteLedger.js';
import { RiteSweeper } from './services/riteSweeper.js';
import { verifyRite } from './services/riteVerifier.js';
import { StripeCreditVerifier, StripeGateway, StripeRiteGateway } from './services/stripeRite.js';
import { GooglePlayGateway, PlayCreditVerifier, PlayGateway, PlayVoidedSync } from './services/playRite.js';
import { parsePackPrices } from './services/ritePacks.js';
import { createIapRouter } from './routes/iap.js';
import { createPyreRouter } from './routes/pyre.js';
import { PurchaseVerifier, RiteRouterDeps, createRiteRouter, recordInPyre } from './routes/rite.js';
import { createStripeWebhookRouter } from './routes/stripeWebhook.js';

/**
 * Loads the treasury key (JSON byte array only). A missing or invalid key
 * returns null and rites stay disabled; no keypair is ever generated instead.
 */
function loadTreasury(): Keypair | null {
  const raw = config.treasuryPrivateKey.trim();
  if (!raw) return null;
  try {
    if (!raw.startsWith('[')) throw new Error('expected a JSON byte array');
    return Keypair.fromSecretKey(Uint8Array.from(JSON.parse(raw)));
  } catch (err: any) {
    console.error(`[rite] Invalid TREASURY_PRIVATE_KEY (${err.message}): rites disabled.`);
    return null;
  }
}

/** The rite services an app is built from; any of them may be off. */
export interface RiteDeps extends Pick<RiteRouterDeps, 'burns' | 'check' | 'stripe'> {
  sweeper?: RiteSweeper | null;
  /** Android payments through Google Play; null when not configured. */
  play?: { gateway: PlayGateway; ledger: RiteLedger } | null;
  voidedSync?: PlayVoidedSync | null;
}

/**
 * The cold owner of the treasury's Joules: null when the server's own key is
 * the owner, undefined (rites off) when the configuration is invalid. On
 * mainnet a separate cold owner is required.
 */
export function treasuryOwner(treasury: Keypair): PublicKey | null | undefined {
  const raw = config.treasuryOwner.trim();
  let owner: PublicKey | null = null;
  if (raw) {
    try {
      owner = new PublicKey(raw);
    } catch {
      console.error('[rite] TREASURY_OWNER is not a valid public key: rites disabled.');
      return undefined;
    }
  }
  if (owner?.equals(treasury.publicKey)) owner = null;
  if (!owner && config.solanaCluster === 'mainnet-beta') {
    console.error('[rite] On mainnet the Joules must belong to a cold TREASURY_OWNER, not the server key: rites disabled.');
    return undefined;
  }
  return owner;
}

/** Google Play from configuration, or null (Android rites off). */
export function playFromConfig(): PlayGateway | null {
  if (!config.googlePlayServiceAccount) return null;
  try {
    return new GooglePlayGateway(config.googlePlayServiceAccount, config.googlePackageName);
  } catch (e: any) {
    console.error(`[play] Invalid GOOGLE_PLAY_SERVICE_ACCOUNT (${e.message}): Android rites off.`);
    return null;
  }
}

/** Stripe from configuration, or null (web payment off) if anything is missing or mismatched. */
export function stripeFromConfig(): StripeGateway | null {
  const { stripeSecretKey: key, stripeWebhookSecret, webOrigin } = config;
  const prices = parsePackPrices(config.stripeRitePrices);
  if (!key || !stripeWebhookSecret || prices.size === 0 || !webOrigin) return null;
  const live = key.startsWith('sk_live_') || key.startsWith('rk_live_');
  if (live !== (config.solanaCluster === 'mainnet-beta')) {
    console.error(`[stripe] A ${live ? 'live' : 'test'} key with cluster ${config.solanaCluster}: web payment off.`);
    return null;
  }
  return new StripeRiteGateway({ secretKey: key, webhookSecret: stripeWebhookSecret, prices, webOrigin });
}

/** The rite services from configuration, or nulls (rites disabled) if anything is missing. */
export function riteFromConfig(): RiteDeps {
  const treasury = loadTreasury();
  let mint: PublicKey | null = null;
  try {
    mint = config.jouleMintAddress ? new PublicKey(config.jouleMintAddress) : null;
  } catch {
    console.error('[rite] JOULE_MINT_ADDRESS is not a valid public key: rites disabled.');
  }
  if (!treasury || !mint) return { burns: null, check: null };
  const owner = treasuryOwner(treasury);
  if (owner === undefined) return { burns: null, check: null };
  const connection = new Connection(config.solanaRpcUrl, 'confirmed');
  const chain = new SolanaRiteChain(connection, treasury, mint, owner ?? undefined);
  const check = (sig: string) => verifyRite(connection, sig, mint, treasury.publicKey, chain.treasuryAccount);
  if (!config.riteLedgerPath) {
    console.error('[rite] No RITE_LEDGER_PATH: rites disabled (fulfilment needs a persistent ledger).');
    return { burns: null, check };
  }
  const ledger = new RiteLedger(config.riteLedgerPath);
  const burns = new RiteBurnService(chain, ledger, { joules: config.riteJoules });
  const gateway = stripeFromConfig();
  const play = playFromConfig();
  return {
    burns,
    check,
    stripe: gateway ? { gateway, ledger } : null,
    sweeper: new RiteSweeper(burns, ledger),
    play: play ? { gateway: play, ledger } : null,
    voidedSync: play ? new PlayVoidedSync(play, ledger) : null,
  };
}

/** Overrides for tests; production builds everything from configuration. */
export interface AppDeps {
  verifier?: PurchaseVerifier;
  rite?: RiteDeps;
}

/** Web purchases go to Stripe, Android to Google Play, the rest to the store validator. */
export function routingVerifier(rite: RiteDeps, stores: PurchaseVerifier): PurchaseVerifier {
  const web = rite.stripe && new StripeCreditVerifier(rite.stripe.gateway, rite.stripe.ledger);
  const android =
    rite.play &&
    new PlayCreditVerifier(rite.play.gateway, rite.play.ledger, {
      testPurchasesOnly: config.solanaCluster !== 'mainnet-beta',
    });
  return {
    verifyReceipt: (p) =>
      p.platform === 'web' && web
        ? web.verify(p.receiptData)
        : p.platform === 'android' && android
          ? android.verify(p.receiptData, p.productId)
          : stores.verifyReceipt(p),
  };
}

export function createApp(deps: AppDeps = {}) {
  const app = express();
  // Behind Fly's proxy, the client's address (for the rate limit) is the
  // entry the proxy appended to X-Forwarded-For, not the proxy's own.
  if (config.trustProxyHops > 0) app.set('trust proxy', config.trustProxyHops);

  // Security and Middleware
  app.use(helmet());
  // CORS: only the configured portal origins (comma-separated CORS_ORIGINS).
  const origins = (process.env.CORS_ORIGINS ?? '').split(',').map((o) => o.trim()).filter(Boolean);
  app.use(cors({ origin: origins.length > 0 ? origins : false }));

  // Initialize Core Services
  const pyreIndexer = new PyreIndexerService();
  const rite = deps.rite ?? riteFromConfig();
  rite.sweeper?.setOnConfirmed((_id, commitment, o) => recordInPyre(pyreIndexer, o.signature, o.joules, commitment));

  // Stripe signs the raw body: its webhook is mounted before JSON parsing.
  app.use('/api/v1/stripe/webhook', createStripeWebhookRouter(rite.stripe ?? null));
  app.use(express.json({ limit: '64kb' }));
  // Basic abuse protection: 120 requests per minute per IP across the API.
  app.use('/api/', rateLimit({ windowMs: 60_000, limit: 120, standardHeaders: 'draft-7', legacyHeaders: false }));

  // Root info
  // Root: no configuration details (cluster, mint, treasury) are exposed.
  app.get('/', (_req, res) => {
    res.json({ service: 'IGNOSIS Relay & Pyre Indexer', status: 'online' });
  });

  // Health check
  app.get('/health', (_req, res) => {
    res.json({
      status: 'healthy',
      timestamp: Date.now(),
      uptime: process.uptime(),
    });
  });

  // Mount Feature Routers
  app.use('/api/v1/iap', createIapRouter());
  app.use('/api/v1/pyre', createPyreRouter(pyreIndexer));
  app.use(
    '/api/v1/rite',
    createRiteRouter({
      verifier: deps.verifier ?? routingVerifier(rite, new ReceiptValidatorService()),
      burns: rite.burns,
      check: rite.check,
      stripe: rite.stripe,
      pyre: pyreIndexer,
      cluster: config.solanaCluster,
    })
  );

  // JSON errors only: malformed bodies and unexpected failures never return
  // Express's HTML page or a stack trace.
  app.use((err: any, _req: Request, res: Response, _next: NextFunction) => {
    const status = typeof err?.status === 'number' && err.status >= 400 && err.status < 500 ? err.status : 500;
    if (status === 500) console.error('[server] Unhandled error', err);
    res.status(status).json({ success: false, error: status === 500 ? 'Internal error' : 'Bad request' });
  });

  return app;
}

const isMainModule = process.argv[1]?.endsWith('/server.js') || process.argv[1]?.endsWith('/server.ts');

if (isMainModule && process.env.NODE_ENV !== 'test') {
  const rite = riteFromConfig();
  const app = createApp({ rite });
  rite.sweeper?.start();
  rite.voidedSync?.start();
  app.listen(config.port, () => {
    console.log(`\n======================================================`);
    console.log(`🔥 IGNOSIS RELAY SERVER LISTENING ON PORT ${config.port}`);
    console.log(`🌐 Cluster: ${config.solanaCluster} | Joule mint: ${config.jouleMintAddress || 'none'}`);
    console.log(
      `🕯  Rites: ${rite.burns ? 'on' : 'off'} | Web payment: ${rite.stripe ? 'on' : 'off'} | Android: ${rite.play ? 'on' : 'off'}`
    );
    console.log(`======================================================\n`);
  });
}
