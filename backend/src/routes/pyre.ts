import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { PyreIndexerService } from '../services/pyreIndexer.js';

export function createPyreRouter(indexer: PyreIndexerService): Router {
  const router = Router();

  // GET /api/v1/pyre/stats
  router.get('/stats', (_req: Request, res: Response) => {
    const stats = indexer.getStats();
    res.json({ success: true, stats });
  });

  // GET /api/v1/pyre/recent
  router.get('/recent', (req: Request, res: Response) => {
    const limit = parseInt((req.query.limit as string) || '20', 10);
    const burns = indexer.getRecentBurns(limit);
    res.json({ success: true, burns });
  });

  // POST /api/v1/pyre/record-burn (Client-side / Relay notification)
  const burnRecordSchema = z.object({
    signature: z.string().min(10),
    practitioner: z.string().min(30),
    amount: z.number().positive().default(93),
    intentHashHex: z.string().length(64),
    source: z.enum(['mobile_app', 'web_portal', 'on_chain_solana']).default('mobile_app'),
  });

  router.post('/record-burn', (req: Request, res: Response) => {
    const parsed = burnRecordSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ success: false, error: parsed.error.format() });
    }

    const { signature, practitioner, amount, intentHashHex, source } = parsed.data;

    const stats = indexer.recordBurn({
      signature,
      practitioner: `${practitioner.substring(0, 6)}...${practitioner.substring(practitioner.length - 4)}`,
      amount,
      intentHashHex,
      timestamp: Date.now(),
      source,
    });

    return res.json({ success: true, stats, message: 'Burn consecrated and recorded in Global Pyre.' });
  });

  // POST /api/v1/pyre/webhook (Helius / QuickNode webhook listener)
  router.post('/webhook', (req: Request, res: Response) => {
    try {
      const events = Array.isArray(req.body) ? req.body : [req.body];
      for (const event of events) {
        if (event && event.signature) {
          indexer.recordBurn({
            signature: event.signature,
            practitioner: event.feePayer ? `${event.feePayer.substring(0, 6)}...` : 'Unknown',
            amount: 93,
            intentHashHex: '0000000000000000000000000000000000000000000000000000000000000000',
            timestamp: Date.now(),
            source: 'on_chain_solana',
          });
        }
      }
      return res.json({ success: true, processed: events.length });
    } catch (err: any) {
      return res.status(500).json({ success: false, error: err.message });
    }
  });

  return router;
}
