import { DatabaseSync } from 'node:sqlite';

export type RiteState = 'pending' | 'done' | 'failed';

/** A paid web purchase (Stripe Checkout session) that buys one rite. */
export interface RiteCredit {
  sessionId: string;
  paymentIntent: string;
  amountTotal: number;
  currency: string;
  /** Revoked by a refund or dispute before it was used. */
  state: 'paid' | 'revoked';
  createdAt: number;
}

export interface RiteRecord {
  /** Store transaction / order ID: each is fulfilled at most once. */
  purchaseId: string;
  commitment: string;
  state: RiteState;
  /** Signature of the latest signed burn for this purchase. */
  signature: string;
  /** The burn can no longer land once the chain passes this block height. */
  lastValidBlockHeight: number;
  /** The signed transaction (base64), so a retry can resend the same burn. */
  rawTx: string;
  updatedAt: number;
}

/**
 * Persistent fulfilment ledger. A burn is written here, signed but unsent,
 * before it is broadcast, so a crash or retry never burns twice for one
 * purchase. SQLite suits a single instance; several instances need a shared
 * database with the same unique key on purchase_id.
 */
export class RiteLedger {
  private db: DatabaseSync;

  constructor(path: string) {
    this.db = new DatabaseSync(path);
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS rites (
        purchase_id TEXT PRIMARY KEY,
        commitment TEXT NOT NULL,
        state TEXT NOT NULL CHECK (state IN ('pending', 'done', 'failed')),
        signature TEXT NOT NULL,
        last_valid_block_height INTEGER NOT NULL,
        raw_tx TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS credits (
        session_id TEXT PRIMARY KEY,
        payment_intent TEXT NOT NULL,
        amount_total INTEGER NOT NULL,
        currency TEXT NOT NULL,
        state TEXT NOT NULL CHECK (state IN ('paid', 'revoked')),
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS credits_payment_intent ON credits (payment_intent);`);
  }

  get(purchaseId: string): RiteRecord | undefined {
    const row = this.db.prepare('SELECT * FROM rites WHERE purchase_id = ?').get(purchaseId) as any;
    if (!row) return undefined;
    return {
      purchaseId: row.purchase_id,
      commitment: row.commitment,
      state: row.state,
      signature: row.signature,
      lastValidBlockHeight: Number(row.last_valid_block_height),
      rawTx: row.raw_tx,
      updatedAt: Number(row.updated_at),
    };
  }

  /** Records the first burn for a purchase. False if one is already recorded. */
  insertPending(r: Omit<RiteRecord, 'state' | 'updatedAt'>): boolean {
    const res = this.db
      .prepare(
        `INSERT OR IGNORE INTO rites
           (purchase_id, commitment, state, signature, last_valid_block_height, raw_tx, updated_at)
         VALUES (?, ?, 'pending', ?, ?, ?, ?)`
      )
      .run(r.purchaseId, r.commitment, r.signature, r.lastValidBlockHeight, r.rawTx, Date.now());
    return res.changes === 1;
  }

  /**
   * Replaces a burn that can no longer land with a new one, only if the
   * record still holds [previousSignature] (so two retries cannot both rebuild).
   */
  replacePending(
    purchaseId: string,
    previousSignature: string,
    next: { signature: string; lastValidBlockHeight: number; rawTx: string }
  ): boolean {
    const res = this.db
      .prepare(
        `UPDATE rites SET state = 'pending', signature = ?, last_valid_block_height = ?, raw_tx = ?, updated_at = ?
         WHERE purchase_id = ? AND signature = ? AND state != 'done'`
      )
      .run(next.signature, next.lastValidBlockHeight, next.rawTx, Date.now(), purchaseId, previousSignature);
    return res.changes === 1;
  }

  mark(purchaseId: string, signature: string, state: 'done' | 'failed'): void {
    this.db
      .prepare(`UPDATE rites SET state = ?, updated_at = ? WHERE purchase_id = ? AND signature = ? AND state != 'done'`)
      .run(state, Date.now(), purchaseId, signature);
  }

  /** Rites not yet confirmed whose last attempt is older than [olderThanMs]. */
  unfinished(olderThanMs: number, limit = 50): Pick<RiteRecord, 'purchaseId' | 'commitment'>[] {
    const rows = this.db
      .prepare(`SELECT purchase_id, commitment FROM rites WHERE state != 'done' AND updated_at <= ? ORDER BY updated_at LIMIT ?`)
      .all(Date.now() - olderThanMs, limit) as any[];
    return rows.map((r) => ({ purchaseId: r.purchase_id, commitment: r.commitment }));
  }

  /** Records a paid web purchase; a repeated webhook changes nothing. */
  recordCredit(c: Omit<RiteCredit, 'state' | 'createdAt'>): void {
    this.db
      .prepare(
        `INSERT OR IGNORE INTO credits (session_id, payment_intent, amount_total, currency, state, created_at)
         VALUES (?, ?, ?, ?, 'paid', ?)`
      )
      .run(c.sessionId, c.paymentIntent, c.amountTotal, c.currency, Date.now());
  }

  getCredit(sessionId: string): RiteCredit | undefined {
    const row = this.db.prepare('SELECT * FROM credits WHERE session_id = ?').get(sessionId) as any;
    if (!row) return undefined;
    return {
      sessionId: row.session_id,
      paymentIntent: row.payment_intent,
      amountTotal: Number(row.amount_total),
      currency: row.currency,
      state: row.state,
      createdAt: Number(row.created_at),
    };
  }

  /**
   * Revokes the unused credits paid by [paymentIntent] (a refund or dispute).
   * A credit already spent on a burn stays: the burn cannot be undone.
   * Returns the number revoked.
   */
  revokeCredits(paymentIntent: string, purchaseIdOf: (sessionId: string) => string): number {
    const rows = this.db
      .prepare(`SELECT session_id FROM credits WHERE payment_intent = ? AND state = 'paid'`)
      .all(paymentIntent) as any[];
    let revoked = 0;
    for (const { session_id } of rows) {
      if (this.get(purchaseIdOf(session_id))) continue;
      revoked += Number(
        this.db.prepare(`UPDATE credits SET state = 'revoked' WHERE session_id = ? AND state = 'paid'`).run(session_id)
          .changes
      );
    }
    return revoked;
  }

  close(): void {
    this.db.close();
  }
}
