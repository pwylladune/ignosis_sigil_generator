import Stripe from 'stripe';
import { PurchaseVerificationResult } from './receiptValidator.js';
import { RiteLedger } from './riteLedger.js';
import { RITE_PACKS, RitePack, ritePackById } from './ritePacks.js';

/** A Checkout session that has been paid for a package of rites and not refunded. */
export interface PaidSession {
  sessionId: string;
  paymentIntent: string;
  amountTotal: number;
  currency: string;
  rites: number;
}

/** A package on sale on the web, with its Stripe price. */
export interface PackOffer {
  id: string;
  rites: number;
  /** In the currency's smallest unit (cents). */
  amount: number;
  currency: string;
}

/** What the rite needs from Stripe; a fake stands in for it in tests. */
export interface StripeGateway {
  createCheckout(pack: RitePack): Promise<{ id: string; url: string }>;
  /** The packages that have a Stripe price, cheapest first. */
  offers(): Promise<PackOffer[]>;
  /** The session if it is ours, paid and not refunded or disputed; otherwise null. */
  retrievePaid(sessionId: string): Promise<PaidSession | null>;
  /** Verifies the Stripe-Signature header; throws if it does not match. */
  parseWebhook(rawBody: Buffer, signature: string): Stripe.Event;
}

/** Marks sessions this server created, so other Checkout traffic is ignored. */
export const RITE_METADATA = { ignosis: 'rite' } as const;

export const CHECKOUT_SESSION_ID = /^cs_(test|live)_[A-Za-z0-9]{10,200}$/;

/** Ledger key of the web payment [sessionId]: its rites are spent against it. */
export const webPurchaseId = (sessionId: string) => `web:${sessionId}`;

/** The package a rite session was opened for (set by this server, not the payer). */
function sessionPack(s: Stripe.Checkout.Session): RitePack | undefined {
  if (s.mode !== 'payment' || s.metadata?.ignosis !== RITE_METADATA.ignosis) return undefined;
  return ritePackById(s.metadata?.pack ?? '');
}

function paidSession(s: Stripe.Checkout.Session): PaidSession | null {
  const pack = sessionPack(s);
  if (!pack || s.payment_status !== 'paid') return null;
  const pi = typeof s.payment_intent === 'string' ? s.payment_intent : s.payment_intent?.id;
  if (!pi) return null;
  return {
    sessionId: s.id,
    paymentIntent: pi,
    amountTotal: s.amount_total ?? 0,
    currency: s.currency ?? '',
    rites: pack.rites,
  };
}

export interface StripeRiteOptions {
  secretKey: string;
  webhookSecret: string;
  /** Stripe price per package ID. */
  prices: Map<string, string>;
  /** The web app's origin; Stripe returns the payer to a page there. */
  webOrigin: string;
}

export class StripeRiteGateway implements StripeGateway {
  private readonly stripe: Stripe;
  private cached: { offers: PackOffer[]; until: number } | null = null;

  constructor(private readonly options: StripeRiteOptions) {
    this.stripe = new Stripe(options.secretKey);
  }

  async createCheckout(pack: RitePack): Promise<{ id: string; url: string }> {
    const price = this.options.prices.get(pack.id);
    if (!price) throw new Error(`No Stripe price for ${pack.id}`);
    const back = `${this.options.webOrigin}/rite-paid.html`;
    const metadata = { ...RITE_METADATA, pack: pack.id };
    const session = await this.stripe.checkout.sessions.create({
      mode: 'payment',
      line_items: [{ price, quantity: 1 }],
      success_url: back,
      cancel_url: `${back}?cancelled=1`,
      metadata,
      payment_intent_data: { metadata },
    });
    if (!session.url) throw new Error('Stripe returned no Checkout URL');
    return { id: session.id, url: session.url };
  }

  async retrievePaid(sessionId: string): Promise<PaidSession | null> {
    const s = await this.stripe.checkout.sessions.retrieve(sessionId, {
      expand: ['payment_intent.latest_charge'],
    });
    const paid = paidSession(s);
    if (!paid) return null;
    const charge = (s.payment_intent as Stripe.PaymentIntent | null)?.latest_charge;
    if (charge && typeof charge !== 'string' && (charge.amount_refunded > 0 || charge.disputed)) return null;
    return paid;
  }

  /** Prices as Stripe holds them, read at most every ten minutes. */
  async offers(): Promise<PackOffer[]> {
    if (this.cached && this.cached.until > Date.now()) return this.cached.offers;
    const offers: PackOffer[] = [];
    for (const pack of RITE_PACKS) {
      const id = this.options.prices.get(pack.id);
      if (!id) continue;
      const price = await this.stripe.prices.retrieve(id);
      if (!price.active || price.unit_amount == null) continue;
      offers.push({ id: pack.id, rites: pack.rites, amount: price.unit_amount, currency: price.currency });
    }
    offers.sort((a, b) => a.rites - b.rites);
    this.cached = { offers, until: Date.now() + 10 * 60_000 };
    return offers;
  }

  parseWebhook(rawBody: Buffer, signature: string): Stripe.Event {
    return this.stripe.webhooks.constructEvent(rawBody, signature, this.options.webhookSecret);
  }
}

/**
 * Applies a verified Stripe event to the ledger: a paid rite session becomes
 * a credit; a refund or dispute revokes the payment's unused credits. Other
 * events are ignored. Returns what it did, for logs and tests.
 */
export function applyStripeEvent(event: Stripe.Event, ledger: RiteLedger): 'credited' | 'revoked' | 'ignored' {
  switch (event.type) {
    case 'checkout.session.completed':
    case 'checkout.session.async_payment_succeeded': {
      const paid = paidSession(event.data.object);
      if (!paid) return 'ignored';
      ledger.recordCredit(paid);
      return 'credited';
    }
    case 'charge.refunded':
    case 'charge.dispute.created': {
      const obj = event.data.object as Stripe.Charge | Stripe.Dispute;
      const pi = typeof obj.payment_intent === 'string' ? obj.payment_intent : obj.payment_intent?.id;
      if (!pi) return 'ignored';
      return ledger.revokeCredits(pi) > 0 ? 'revoked' : 'ignored';
    }
    default:
      return 'ignored';
  }
}

/**
 * Verifies a web purchase: [receiptData] is the Checkout session ID. The
 * ledger's credit (from the webhook) decides; if the webhook has not arrived
 * yet, Stripe is asked directly and the credit recorded. A revoked credit is
 * never valid. The result names the package's product, which sets how many
 * rites the payment buys.
 */
export class StripeCreditVerifier {
  constructor(
    private readonly gateway: StripeGateway,
    private readonly ledger: RiteLedger
  ) {}

  async verify(sessionId: string): Promise<PurchaseVerificationResult> {
    const invalid = (errorMessage: string): PurchaseVerificationResult => ({
      isValid: false,
      productId: '',
      transactionId: '',
      purchaseTime: Date.now(),
      environment: sessionId.startsWith('cs_live_') ? 'production' : 'sandbox',
      errorMessage,
    });
    if (!CHECKOUT_SESSION_ID.test(sessionId)) return invalid('Not a Checkout session ID');

    let credit = this.ledger.getCredit(sessionId);
    if (!credit) {
      const paid = await this.gateway.retrievePaid(sessionId).catch(() => null);
      if (!paid) return invalid('Session is not a paid rite');
      this.ledger.recordCredit(paid);
      credit = this.ledger.getCredit(sessionId)!;
    }
    if (credit.state !== 'paid') return invalid('Payment was refunded or disputed');
    const pack = RITE_PACKS.find((p) => p.rites === credit.rites);
    if (!pack) return invalid('Not a rite package');
    return {
      isValid: true,
      productId: pack.productId,
      transactionId: sessionId,
      purchaseTime: credit.createdAt,
      environment: sessionId.startsWith('cs_live_') ? 'production' : 'sandbox',
    };
  }
}
