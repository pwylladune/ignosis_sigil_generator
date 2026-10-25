import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { SolanaTreasuryService } from '../services/solanaTreasury.js';
import { ReceiptValidatorService } from '../services/receiptValidator.js';
import { config } from '../config.js';

export function createIapRouter(
  treasury: SolanaTreasuryService,
  receiptValidator: ReceiptValidatorService
): Router {
  const router = Router();

  const fulfillSchema = z.object({
    walletAddress: z.string().min(32).max(44),
    platform: z.enum(['ios', 'android', 'mock']),
    receiptData: z.string().min(1),
    productId: z.string().default('com.ignosis.pack.ignition_279'),
    transactionId: z.string().optional(),
  });

  router.post('/fulfill-starter-pack', async (req: Request, res: Response) => {
    try {
      const parsed = fulfillSchema.safeParse(req.body);
      if (!parsed.success) {
        return res.status(400).json({
          success: false,
          error: 'Invalid request body',
          details: parsed.error.format(),
        });
      }

      const { walletAddress, platform, receiptData, productId, transactionId } = parsed.data;

      // 1. Validate in-app purchase receipt
      const verification = await receiptValidator.verifyReceipt({
        platform,
        receiptData,
        productId,
        transactionId,
      });

      if (!verification.isValid) {
        return res.status(402).json({
          success: false,
          error: 'Receipt verification failed',
          details: verification.errorMessage,
        });
      }

      // 2. Dispense 279 $IGNOSIS tokens from Treasury
      const dispenseResult = await treasury.dispenseTokens(
        walletAddress,
        config.starterPackTokenAmount
      );

      return res.status(200).json({
        success: true,
        receiptVerified: true,
        storeTransactionId: verification.transactionId,
        solanaTxSignature: dispenseResult.txSignature,
        tokensDispatched: dispenseResult.tokensDispatched,
        recipientAddress: dispenseResult.destinationAddress,
        cluster: dispenseResult.cluster,
        isSimulated: dispenseResult.isSimulated,
        message: dispenseResult.message,
      });
    } catch (err: any) {
      console.error('[IAP Route Error]', err);
      return res.status(500).json({
        success: false,
        error: 'Internal fulfillment error',
        message: err.message,
      });
    }
  });

  return router;
}
