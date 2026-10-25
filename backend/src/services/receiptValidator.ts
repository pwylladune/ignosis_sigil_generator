export interface PurchaseVerificationResult {
  isValid: boolean;
  productId: string;
  transactionId: string;
  purchaseTime: number;
  environment: 'production' | 'sandbox' | 'mock';
  errorMessage?: string;
}

export class ReceiptValidatorService {
  /**
   * Validates in-app purchase receipts from Apple StoreKit 2 or Google Play
   */
  public async verifyReceipt(params: {
    platform: 'ios' | 'android' | 'mock';
    receiptData: string;
    productId: string;
    transactionId?: string;
  }): Promise<PurchaseVerificationResult> {
    const { platform, productId, transactionId } = params;

    // Fail closed. There is no development bypass and no "accept any
    // non-empty receipt" path: real verification needs the App Store Server
    // API (JWS chain) or the Google Play Developer API, plus an idempotent
    // ledger keyed on transactionId / orderId. Until those exist, nothing is
    // fulfilled. See TASK.md §2.2 C5 and §2.4 option C.
    if (platform === 'ios' || platform === 'android') {
      return {
        isValid: false,
        productId,
        transactionId: transactionId || '',
        purchaseTime: Date.now(),
        environment: 'production',
        errorMessage: `Receipt verification for ${platform} is not implemented; refusing to fulfil.`,
      };
    }

    return {
      isValid: false,
      productId,
      transactionId: transactionId || '',
      purchaseTime: Date.now(),
      environment: 'mock',
      errorMessage: `Unsupported platform: ${platform}`,
    };
  }
}
