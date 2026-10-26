import { createSign } from 'crypto';
import { PurchaseVerificationResult } from './receiptValidator.js';
import { RiteLedger } from './riteLedger.js';

/** A Play in-app purchase as the Play Developer API reports it. */
export interface PlayPurchase {
  /** 0 purchased, 1 cancelled, 2 pending. */
  purchaseState: number;
  /** 0 not yet consumed, 1 consumed. */
  consumptionState: number;
  /** 0 not yet acknowledged, 1 acknowledged. */
  acknowledgementState: number;
  orderId: string;
  /** Present only for test (0), promo (1) or rewarded (2) purchases; absent for real money. */
  purchaseType?: number;
}

/** What the rite needs from Google Play; a fake stands in for it in tests. */
export interface PlayGateway {
  /** The purchase, or null if Play does not know this token for this product. */
  getPurchase(productId: string, purchaseToken: string): Promise<PlayPurchase | null>;
  acknowledge(productId: string, purchaseToken: string): Promise<void>;
  /** Order IDs of in-app purchases refunded, charged back or revoked since [sinceMs]. */
  voidedOrderIds(sinceMs: number): Promise<string[]>;
}

/** Ledger purchase ID for an Android rite paid in Play order [orderId]. */
export const androidPurchaseId = (orderId: string) => `android:${orderId}`;

/** Play purchase tokens: long, URL-safe; anything else is refused before Google is asked. */
export const PLAY_PURCHASE_TOKEN = /^[A-Za-z0-9._-]{20,1024}$/;

const API = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

interface ServiceAccount {
  client_email: string;
  private_key: string;
  token_uri?: string;
}

/**
 * The Play Developer API, authorised as a service account (OAuth 2.0 JWT
 * bearer flow, signed with the account's RSA key; no client library).
 */
export class GooglePlayGateway implements PlayGateway {
  private readonly account: ServiceAccount;
  private token: { value: string; expiresAt: number } | null = null;

  constructor(
    serviceAccountJson: string,
    private readonly packageName: string
  ) {
    const parsed = JSON.parse(serviceAccountJson);
    if (typeof parsed?.client_email !== 'string' || typeof parsed?.private_key !== 'string') {
      throw new Error('Service account JSON lacks client_email or private_key');
    }
    this.account = parsed;
  }

  private async accessToken(): Promise<string> {
    if (this.token && this.token.expiresAt > Date.now() + 60_000) return this.token.value;
    const tokenUri = this.account.token_uri ?? 'https://oauth2.googleapis.com/token';
    const now = Math.floor(Date.now() / 1000);
    const b64 = (o: object) => Buffer.from(JSON.stringify(o)).toString('base64url');
    const unsigned = `${b64({ alg: 'RS256', typ: 'JWT' })}.${b64({
      iss: this.account.client_email,
      scope: SCOPE,
      aud: tokenUri,
      iat: now,
      exp: now + 3600,
    })}`;
    const signature = createSign('RSA-SHA256').update(unsigned).sign(this.account.private_key).toString('base64url');
    const res = await fetch(tokenUri, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: `${unsigned}.${signature}`,
      }),
    });
    const body: any = await res.json();
    if (!res.ok || typeof body.access_token !== 'string') throw new Error(`Google token request failed (${res.status})`);
    this.token = { value: body.access_token, expiresAt: Date.now() + Number(body.expires_in ?? 3600) * 1000 };
    return this.token.value;
  }

  private async call(path: string, init: RequestInit = {}): Promise<Response> {
    return fetch(`${API}/${encodeURIComponent(this.packageName)}${path}`, {
      ...init,
      headers: { Authorization: `Bearer ${await this.accessToken()}`, ...(init.headers ?? {}) },
    });
  }

  async getPurchase(productId: string, purchaseToken: string): Promise<PlayPurchase | null> {
    const res = await this.call(
      `/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}`
    );
    if (res.status === 400 || res.status === 404 || res.status === 410) return null;
    if (!res.ok) throw new Error(`Play purchase lookup failed (${res.status})`);
    const b: any = await res.json();
    return {
      purchaseState: Number(b.purchaseState ?? 0),
      consumptionState: Number(b.consumptionState ?? 0),
      acknowledgementState: Number(b.acknowledgementState ?? 0),
      orderId: String(b.orderId ?? ''),
      purchaseType: b.purchaseType === undefined ? undefined : Number(b.purchaseType),
    };
  }

  async acknowledge(productId: string, purchaseToken: string): Promise<void> {
    const res = await this.call(
      `/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`,
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' }
    );
    if (!res.ok) throw new Error(`Play acknowledge failed (${res.status})`);
  }

  async voidedOrderIds(sinceMs: number): Promise<string[]> {
    const ids: string[] = [];
    let pageToken = '';
    do {
      // type=0: in-app products only.
      const q = new URLSearchParams({ startTime: String(sinceMs), type: '0', maxResults: '1000' });
      if (pageToken) q.set('token', pageToken);
      const res = await this.call(`/purchases/voidedpurchases?${q}`);
      if (!res.ok) throw new Error(`Play voided purchases failed (${res.status})`);
      const b: any = await res.json();
      for (const v of b.voidedPurchases ?? []) if (v.orderId) ids.push(String(v.orderId));
      pageToken = b.tokenPagination?.nextPageToken ?? '';
    } while (pageToken);
    return ids;
  }
}

export interface PlayVerifierOptions {
  /** Products that buy a rite. */
  riteProductIds: string[];
  /**
   * Whether purchases must be Play test purchases (license testers). True off
   * mainnet, so real money never buys a devnet burn; false on mainnet, so a
   * test purchase never burns real Joules.
   */
  testPurchasesOnly: boolean;
}

/**
 * Verifies an Android rite: [purchaseToken] is the Play purchase token. Play
 * decides whether it is a completed purchase of a rite product; the ledger
 * decides whether a refund has revoked it. A purchase is acknowledged here, so
 * Play does not refund it after three days, and consumed by the app only after
 * its burn is confirmed. A consumed purchase is valid only to look up its own
 * earlier burn.
 */
export class PlayCreditVerifier {
  constructor(
    private readonly gateway: PlayGateway,
    private readonly ledger: RiteLedger,
    private readonly options: PlayVerifierOptions
  ) {}

  async verify(purchaseToken: string, productId: string): Promise<PurchaseVerificationResult> {
    const invalid = (errorMessage: string): PurchaseVerificationResult => ({
      isValid: false,
      productId: '',
      transactionId: '',
      purchaseTime: Date.now(),
      environment: this.options.testPurchasesOnly ? 'sandbox' : 'production',
      errorMessage,
    });
    if (!this.options.riteProductIds.includes(productId)) return invalid('Not a rite product');
    if (!PLAY_PURCHASE_TOKEN.test(purchaseToken)) return invalid('Not a Play purchase token');

    const p = await this.gateway.getPurchase(productId, purchaseToken).catch(() => null);
    if (!p || p.purchaseState !== 0 || !p.orderId) return invalid('Not a completed purchase');
    if ((p.purchaseType === 0) !== this.options.testPurchasesOnly) {
      return invalid(this.options.testPurchasesOnly ? 'Real purchases are refused here' : 'Test purchases are refused here');
    }
    const spent = this.ledger.get(androidPurchaseId(p.orderId));
    if (p.consumptionState === 1 && !spent) return invalid('Purchase already consumed');

    this.ledger.recordCredit({ sessionId: p.orderId, paymentIntent: p.orderId, amountTotal: 0, currency: '' });
    if (this.ledger.getCredit(p.orderId)?.state !== 'paid') return invalid('Payment was refunded or revoked');
    if (p.acknowledgementState === 0) {
      // Best effort: the app acknowledges too, and the next request retries.
      await this.gateway.acknowledge(productId, purchaseToken).catch((e) => console.error(`[play] ${e.message}`));
    }
    return {
      isValid: true,
      productId,
      transactionId: p.orderId,
      purchaseTime: Date.now(),
      environment: this.options.testPurchasesOnly ? 'sandbox' : 'production',
    };
  }
}

/**
 * Revokes unused Android credits that Play reports voided (refunds,
 * chargebacks, revocations). A burn already made stays.
 */
export class PlayVoidedSync {
  private timer: NodeJS.Timeout | null = null;

  constructor(
    private readonly gateway: PlayGateway,
    private readonly ledger: RiteLedger,
    private readonly windowMs = 3 * 24 * 3600_000
  ) {}

  async runOnce(): Promise<number> {
    const ids = await this.gateway.voidedOrderIds(Date.now() - this.windowMs);
    let revoked = 0;
    for (const id of ids) revoked += this.ledger.revokeCredits(id, androidPurchaseId);
    if (revoked) console.log(`[play] revoked ${revoked} refunded credit(s)`);
    return revoked;
  }

  start(intervalMs = 15 * 60_000): void {
    if (this.timer) return;
    this.timer = setInterval(() => void this.runOnce().catch((e) => console.error(`[play] ${e.message}`)), intervalMs);
    this.timer.unref();
  }

  stop(): void {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }
}
