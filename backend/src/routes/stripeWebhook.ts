import express, { Router, Request, Response } from 'express';
import { RiteLedger } from '../services/riteLedger.js';
import { StripeGateway, applyStripeEvent } from '../services/stripeRite.js';

/**
 * POST /api/v1/stripe/webhook. Stripe signs the raw body, so this router
 * parses it itself and must be mounted before express.json(). Unsigned or
 * mis-signed requests are refused; verified events update the credits.
 */
export function createStripeWebhookRouter(deps: { gateway: StripeGateway; ledger: RiteLedger } | null): Router {
  const router = Router();
  router.post('/', express.raw({ type: 'application/json', limit: '256kb' }), (req: Request, res: Response) => {
    if (!deps) return res.status(503).json({ received: false });
    const signature = req.header('stripe-signature');
    if (!signature || !Buffer.isBuffer(req.body)) return res.status(400).json({ received: false });
    let event;
    try {
      event = deps.gateway.parseWebhook(req.body, signature);
    } catch {
      return res.status(400).json({ received: false });
    }
    const result = applyStripeEvent(event, deps.ledger);
    if (result !== 'ignored') console.log(`[stripe] ${event.type} ${event.id}: ${result}`);
    return res.json({ received: true });
  });
  return router;
}
