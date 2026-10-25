import { Router, Request, Response } from 'express';
import { SolanaTreasuryService } from '../services/solanaTreasury.js';
import { ReceiptValidatorService } from '../services/receiptValidator.js';

/**
 * The $1.99 "Ignition Starter Pack" (an IAP fulfilled with crypto tokens) is
 * discontinued: v1.0 ships with no token, and selling a token through IAP is
 * high-risk under App Store / Play policy (TASK.md §2.3). The route answers
 * 410 Gone without validating or dispensing anything, so old clients get a
 * clear, final answer.
 */
export function createIapRouter(
  _treasury: SolanaTreasuryService,
  _receiptValidator: ReceiptValidatorService
): Router {
  const router = Router();

  router.post('/fulfill-starter-pack', (_req: Request, res: Response) => {
    res.status(410).json({
      success: false,
      error: 'The Ignition Starter Pack has been discontinued.',
    });
  });

  return router;
}
