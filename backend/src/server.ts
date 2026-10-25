import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { config } from './config.js';
import { SolanaTreasuryService } from './services/solanaTreasury.js';
import { ReceiptValidatorService } from './services/receiptValidator.js';
import { PyreIndexerService } from './services/pyreIndexer.js';
import { createIapRouter } from './routes/iap.js';
import { createPyreRouter } from './routes/pyre.js';

export function createApp() {
  const app = express();

  // Security and Middleware
  app.use(helmet());
  app.use(cors({ origin: '*' }));
  app.use(express.json({ limit: '1mb' }));

  // Initialize Core Services
  const treasuryService = new SolanaTreasuryService();
  const receiptValidator = new ReceiptValidatorService();
  const pyreIndexer = new PyreIndexerService();

  // Root info
  app.get('/', (_req, res) => {
    res.json({
      service: 'IGNOSIS Relay & Pyre Indexer',
      version: '1.0.0',
      status: 'online',
      cluster: config.solanaCluster,
      mintAddress: config.ignosisMintAddress,
      treasuryPublicAddress: treasuryService.getTreasuryPublicKey(),
      endpoints: {
        health: '/health',
        pyreStats: '/api/v1/pyre/stats',
        pyreRecent: '/api/v1/pyre/recent',
        fulfillStarterPack: 'POST /api/v1/iap/fulfill-starter-pack',
      },
    });
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
  app.use('/api/v1/iap', createIapRouter(treasuryService, receiptValidator));
  app.use('/api/v1/pyre', createPyreRouter(pyreIndexer));

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
