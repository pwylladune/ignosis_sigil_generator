import { timingSafeEqual } from 'crypto';
import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { PyreIndexerService } from '../services/pyreIndexer.js';

/**
 * Writes require the shared secret in `x-pyre-secret` (PYRE_WRITE_SECRET).
 * Without it configured, write endpoints are disabled, so nobody can inflate
 * the stats anonymously (TASK.md C9).
 */
function requireWriteSecret(req: Request, res: Response): boolean {
  const secret = process.env.PYRE_WRITE_SECRET;
  if (!secret) {
    res.status(503).json({ success: false, error: 'Pyre writes are disabled' });
    return false;
  }
  const given = Buffer.from(req.header('x-pyre-secret') ?? '', 'utf8');
  const expected = Buffer.from(secret, 'utf8');
  // Constant-time comparison (lengths must match for timingSafeEqual).
  if (given.length !== expected.length || !timingSafeEqual(given, expected)) {
    res.status(401).json({ success: false, error: 'Unauthorized' });
    return false;
  }
  return true;
}

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
    if (!requireWriteSecret(req, res)) return;
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

  // POST /api/v1/pyre/webhook (indexer webhook)
  // Records only events that carry a real amount and intent commitment; it
  // never invents values. Parsing provider payloads (e.g. Helius enhanced
  // transactions, SPL Memo) belongs to the v1.1 indexer (TASK.md §2.4 B).
  const webhookEventSchema = z.object({
    signature: z.string().min(10),
    feePayer: z.string().min(30),
    amount: z.number().positive(),
    intentHashHex: z.string().regex(/^[0-9a-f]{64}$/i),
  });

  router.post('/webhook', (req: Request, res: Response) => {
    if (!requireWriteSecret(req, res)) return;
    const events = Array.isArray(req.body) ? req.body : [req.body];
    let recorded = 0;
    for (const raw of events) {
      const parsed = webhookEventSchema.safeParse(raw);
      if (!parsed.success) continue;
      const e = parsed.data;
      indexer.recordBurn({
        signature: e.signature,
        practitioner: `${e.feePayer.substring(0, 6)}...`,
        amount: e.amount,
        intentHashHex: e.intentHashHex.toLowerCase(),
        timestamp: Date.now(),
        source: 'on_chain_solana',
      });
      recorded++;
    }
    return res.json({ success: true, received: events.length, recorded });
  });

  return router;
}
