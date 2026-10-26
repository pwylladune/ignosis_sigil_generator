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
import { verifyRite } from './services/riteVerifier.js';
import { createIapRouter } from './routes/iap.js';
import { createPyreRouter } from './routes/pyre.js';
import { PurchaseVerifier, RiteRouterDeps, createRiteRouter } from './routes/rite.js';

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

/** The rite services from configuration, or nulls (rites disabled) if anything is missing. */
function riteFromConfig(): Pick<RiteRouterDeps, 'burns' | 'check'> {
  const treasury = loadTreasury();
  let mint: PublicKey | null = null;
  try {
    mint = config.jouleMintAddress ? new PublicKey(config.jouleMintAddress) : null;
  } catch {
    console.error('[rite] JOULE_MINT_ADDRESS is not a valid public key: rites disabled.');
  }
  if (!treasury || !mint) return { burns: null, check: null };
  const connection = new Connection(config.solanaRpcUrl, 'confirmed');
  const check = (sig: string) => verifyRite(connection, sig, mint, treasury.publicKey);
  if (!config.riteLedgerPath) {
    console.error('[rite] No RITE_LEDGER_PATH: rites disabled (fulfilment needs a persistent ledger).');
    return { burns: null, check };
  }
  const chain = new SolanaRiteChain(connection, treasury, mint);
  const burns = new RiteBurnService(chain, new RiteLedger(config.riteLedgerPath), { joules: config.riteJoules });
  return { burns, check };
}

/** Overrides for tests; production builds everything from configuration. */
export interface AppDeps {
  verifier?: PurchaseVerifier;
  rite?: Pick<RiteRouterDeps, 'burns' | 'check'>;
}

export function createApp(deps: AppDeps = {}) {
  const app = express();

  // Security and Middleware
  app.use(helmet());
  // CORS: only the configured portal origins (comma-separated CORS_ORIGINS).
  const origins = (process.env.CORS_ORIGINS ?? '').split(',').map((o) => o.trim()).filter(Boolean);
  app.use(cors({ origin: origins.length > 0 ? origins : false }));
  app.use(express.json({ limit: '64kb' }));
  // Basic abuse protection: 120 requests per minute per IP across the API.
  app.use('/api/', rateLimit({ windowMs: 60_000, limit: 120, standardHeaders: 'draft-7', legacyHeaders: false }));

  // Initialize Core Services
  const pyreIndexer = new PyreIndexerService();
  const rite = deps.rite ?? riteFromConfig();

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
      verifier: deps.verifier ?? new ReceiptValidatorService(),
      ...rite,
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
  const app = createApp();
  app.listen(config.port, () => {
    console.log(`\n======================================================`);
    console.log(`🔥 IGNOSIS RELAY SERVER LISTENING ON PORT ${config.port}`);
    console.log(`🌐 Cluster: ${config.solanaCluster} | Joule mint: ${config.jouleMintAddress || 'none'}`);
    console.log(`======================================================\n`);
  });
}
