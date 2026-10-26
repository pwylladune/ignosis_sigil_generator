import { Router, Request, Response } from 'express';

/**
 * The $1.99 "Ignition Starter Pack" (an IAP fulfilled with crypto tokens) is
 * discontinued: users never receive tokens. A purchase now buys a rite, whose
 * Joules are burnt by the treasury (routes/rite.ts). The route answers 410
 * Gone without validating or dispensing anything, so old clients get a clear,
 * final answer.
 */
export function createIapRouter(): Router {
  const router = Router();

  router.post('/fulfill-starter-pack', (_req: Request, res: Response) => {
    res.status(410).json({
      success: false,
      error: 'The Ignition Starter Pack has been discontinued.',
    });
  });

  return router;
}
