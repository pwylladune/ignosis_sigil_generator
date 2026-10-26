import express, { NextFunction, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { config } from './config.js';
import { PyreIndexerService } from './services/pyreIndexer.js';
import { createIapRouter } from './routes/iap.js';
import { createPyreRouter } from './routes/pyre.js';

export function createApp() {
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
    console.log(`🌐 Cluster: ${config.solanaCluster} | Mint: ${config.ignosisMintAddress}`);
    console.log(`======================================================\n`);
  });
}
