import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { config } from '../config.js';
import { PurchaseVerificationResult } from '../services/receiptValidator.js';
import { RiteBurnService } from '../services/riteBurn.js';
import { RiteCheck, explorerUrl } from '../services/riteVerifier.js';
import { PyreIndexerService } from '../services/pyreIndexer.js';
import { RiteLedger } from '../services/riteLedger.js';
import { CHECKOUT_SESSION_ID, StripeGateway, webPurchaseId } from '../services/stripeRite.js';

export interface PurchaseVerifier {
  verifyReceipt(params: {
    platform: 'ios' | 'android' | 'web';
    receiptData: string;
    productId: string;
    transactionId?: string;
  }): Promise<PurchaseVerificationResult>;
}

export interface RiteRouterDeps {
  verifier: PurchaseVerifier;
  /** Null when the mint, treasury or ledger is not configured. */
  burns: RiteBurnService | null;
  check: ((signature: string) => Promise<RiteCheck>) | null;
  pyre: PyreIndexerService;
  cluster: string;
  /** Web payments through Stripe Checkout; null when Stripe is not configured. */
  stripe?: { gateway: StripeGateway; ledger: RiteLedger } | null;
}

/** Adds a first-time confirmed burn to the Global Pyre. */
export function recordInPyre(pyre: PyreIndexerService, signature: string, joules: number, commitment: string) {
  pyre.recordBurn({
    signature,
    practitioner: 'treasury',
    amount: joules,
    intentHashHex: commitment,
    timestamp: Date.now(),
    source: 'on_chain_solana',
  });
}

const consecrateSchema = z.object({
  platform: z.enum(['ios', 'android', 'web']),
  productId: z.string().min(1).max(128),
  receiptData: z.string().min(1).max(60_000),
  transactionId: z.string().min(1).max(128).optional(),
  commitment: z.string().regex(/^[0-9a-f]{64}$/),
});

const signatureSchema = z.string().regex(/^[1-9A-HJ-NP-Za-km-z]{64,90}$/);

/**
 * The rite: a verified purchase burns the rite's Joules on-chain with the
 * user's intent commitment in the memo (ADR 2026-10-25-ignosis-joule-token).
 * Success means the burn is confirmed; nothing is reported before that.
 */
export function createRiteRouter(deps: RiteRouterDeps): Router {
  const router = Router();

  // POST /api/v1/rite/consecrate
  router.post('/consecrate', async (req: Request, res: Response) => {
    const burns = deps.burns;
    if (!burns) return res.status(503).json({ success: false, error: 'Rites are not available' });
    const parsed = consecrateSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ success: false, error: 'Invalid request body' });
    const { platform, productId, receiptData, transactionId, commitment } = parsed.data;

    const purchase = await deps.verifier.verifyReceipt({ platform, receiptData, productId, transactionId });
    // The store's own record decides the product and the purchase ID, not the client.
    if (!purchase.isValid || !purchase.transactionId) {
      return res.status(402).json({ success: false, error: 'Purchase could not be verified' });
    }
    if (!config.riteProductIds.includes(purchase.productId)) {
      return res.status(400).json({ success: false, error: 'This product is not a rite' });
    }

    const outcome = await burns.fulfil(`${platform}:${purchase.transactionId}`, commitment);
    switch (outcome.status) {
      case 'confirmed':
        // Count each burn once, not again when a client asks a second time.
        if (outcome.firstConfirmation) recordInPyre(deps.pyre, outcome.signature, outcome.joules, commitment);
        return res.json({
          success: true,
          signature: outcome.signature,
          joules: outcome.joules,
          explorerUrl: explorerUrl(outcome.signature, deps.cluster),
        });
      case 'pending':
        return res.status(202).json({ success: false, pending: true, signature: outcome.signature });
      case 'conflict':
        return res.status(409).json({ success: false, error: 'This purchase was used for another rite' });
      case 'failed':
        console.error(`[rite] Burn failed: ${outcome.reason}`);
        return res.status(502).json({ success: false, error: 'The burn did not go through; try again' });
    }
  });

  // POST /api/v1/rite/checkout: a Stripe Checkout session for one rite. The
  // session ID is the payer's credit; it is spent at /consecrate on release.
  router.post('/checkout', async (_req: Request, res: Response) => {
    if (!deps.burns || !deps.stripe) return res.status(503).json({ success: false, error: 'Web payment is not available' });
    try {
      const { id, url } = await deps.stripe.gateway.createCheckout();
      return res.json({ success: true, sessionId: id, url });
    } catch (e: any) {
      console.error(`[rite] Checkout failed: ${e.message}`);
      return res.status(502).json({ success: false, error: 'Could not start checkout' });
    }
  });

  // GET /api/v1/rite/credit/:sessionId: is this payment ready to spend, or spent?
  router.get('/credit/:sessionId', async (req: Request, res: Response) => {
    const stripe = deps.stripe;
    if (!stripe) return res.status(503).json({ success: false, error: 'Web payment is not available' });
    const sessionId = req.params.sessionId;
    if (!CHECKOUT_SESSION_ID.test(sessionId)) return res.status(400).json({ success: false, error: 'Invalid session' });
    let credit = stripe.ledger.getCredit(sessionId);
    if (!credit) {
      // The webhook may not have arrived yet: ask Stripe.
      const paid = await stripe.gateway.retrievePaid(sessionId).catch(() => null);
      if (paid) {
        stripe.ledger.recordCredit(paid);
        credit = stripe.ledger.getCredit(sessionId);
      }
    }
    const rite = stripe.ledger.get(webPurchaseId(sessionId));
    return res.json({
      success: true,
      paid: credit?.state === 'paid',
      revoked: credit?.state === 'revoked',
      spent: !!rite,
      burnt: rite?.state === 'done',
      signature: rite?.signature ?? null,
    });
  });

  // GET /api/v1/rite/:signature: the on-chain check, for anyone.
  router.get('/:signature', async (req: Request, res: Response) => {
    if (!deps.check) return res.status(503).json({ success: false, error: 'Rites are not available' });
    const sig = signatureSchema.safeParse(req.params.signature);
    if (!sig.success) return res.status(400).json({ success: false, error: 'Invalid signature' });
    const result = await deps.check(sig.data);
    if (!result.valid) return res.status(404).json({ success: false, error: result.reason });
    return res.json({ success: true, ...result, explorerUrl: explorerUrl(sig.data, deps.cluster) });
  });

  return router;
}
