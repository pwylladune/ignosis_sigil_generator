import { Connection, Keypair, PublicKey, SendTransactionError, Transaction } from '@solana/web3.js';
import { createBurnCheckedInstruction, getAssociatedTokenAddressSync, getMint } from '@solana/spl-token';
import {
  JOULE_DECIMALS,
  JOULE_PROGRAM_ID,
  base58,
  createMemoInstruction,
  isCommitment,
  jouleMintProblem,
  riteMemo,
} from './joule.js';
import { RiteAllowance, RiteLedger, RiteRecord } from './riteLedger.js';

/** A burn signed and ready to send, but not yet sent. */
export interface PreparedBurn {
  signature: string;
  rawTx: string;
  lastValidBlockHeight: number;
}

/** What the fulfilment needs from the chain; a fake stands in for it in tests. */
export interface RiteChain {
  prepareBurn(memo: string, joules: number): Promise<PreparedBurn>;
  /** Broadcasts a signed burn. Throws `RiteRejected` if the chain refuses it. */
  send(rawTx: string): Promise<void>;
  status(signature: string): Promise<'confirmed' | 'failed' | 'unknown'>;
  blockHeight(): Promise<number>;
}

/** The chain refused the transaction outright (e.g. a failed simulation). */
export class RiteRejected extends Error {}

export type RiteOutcome =
  /** [firstConfirmation] is false when this purchase was already reported as confirmed. */
  | { status: 'confirmed'; signature: string; joules: number; firstConfirmation: boolean }
  /** Sent but not yet confirmed: ask again later with the same purchase. */
  | { status: 'pending'; signature: string }
  | { status: 'failed'; reason: string }
  /** The purchase was already used for a different commitment. */
  | { status: 'conflict' }
  /** Every rite the payment bought is already spent. */
  | { status: 'exhausted' };

export interface RiteBurnOptions {
  joules: number;
  pollMs?: number;
  timeoutMs?: number;
}

/**
 * Burns the rite's joules once per verified purchase and reports success only
 * after the burn is confirmed on-chain.
 *
 * Each burn is signed and written to the ledger before it is sent. A retry
 * first asks the chain whether that exact signature landed, and builds a new
 * burn only once the old one has failed or can no longer land (its blockhash
 * has expired). So a crash, a timeout or two concurrent requests never burn
 * twice for one purchase.
 */
export class RiteBurnService {
  private readonly joules: number;
  private readonly pollMs: number;
  private readonly timeoutMs: number;

  constructor(
    private readonly chain: RiteChain,
    private readonly ledger: RiteLedger,
    options: RiteBurnOptions
  ) {
    this.joules = options.joules;
    this.pollMs = options.pollMs ?? 1000;
    this.timeoutMs = options.timeoutMs ?? 45_000;
  }

  get joulesPerRite(): number {
    return this.joules;
  }

  /** Rites the payment [allowance] still has to spend. */
  ritesLeft(allowance: RiteAllowance): number {
    return Math.max(0, allowance.rites - this.ledger.ritesSpent(allowance.key));
  }

  /**
   * Burns once for [purchaseId]. A new rite is spent from [allowance] when
   * given, and refused once the payment's rites are all spent; an existing
   * rite is always finished, so the sweeper needs no allowance.
   */
  async fulfil(purchaseId: string, commitment: string, allowance?: RiteAllowance): Promise<RiteOutcome> {
    if (!purchaseId) return { status: 'failed', reason: 'No purchase ID' };
    if (!isCommitment(commitment)) return { status: 'failed', reason: 'Invalid commitment' };

    const existing = this.ledger.get(purchaseId);
    if (existing && existing.commitment !== commitment) return { status: 'conflict' };
    if (existing?.state === 'done') return this.confirmed(existing.signature, false);

    if (existing) {
      const status = await this.chain.status(existing.signature);
      if (status === 'confirmed') {
        this.ledger.mark(purchaseId, existing.signature, 'done');
        return this.confirmed(existing.signature, true);
      }
      if (
        existing.state === 'pending' &&
        status === 'unknown' &&
        (await this.chain.blockHeight()) <= existing.lastValidBlockHeight
      ) {
        // Still able to land: resend the same signed burn, never a second one.
        return this.sendAndConfirm(existing);
      }
      // Failed, or expired without landing: nothing was burnt, so burn anew.
      const next = await this.chain.prepareBurn(riteMemo(commitment), this.joules);
      if (!this.ledger.replacePending(purchaseId, existing.signature, next)) {
        return { status: 'pending', signature: this.ledger.get(purchaseId)?.signature ?? existing.signature };
      }
      return this.sendAndConfirm({ ...existing, ...next, state: 'pending' });
    }

    if (allowance && this.ritesLeft(allowance) === 0) return { status: 'exhausted' };
    const prepared = await this.chain.prepareBurn(riteMemo(commitment), this.joules);
    if (!this.ledger.insertPending({ purchaseId, commitment, ...prepared }, allowance)) {
      // A concurrent request recorded this purchase first; it owns the burn.
      // Or, with nothing recorded, another took the payment's last rite.
      const winner = this.ledger.get(purchaseId);
      if (!winner) return { status: 'exhausted' };
      if (winner.commitment !== commitment) return { status: 'conflict' };
      return { status: 'pending', signature: winner.signature };
    }
    return this.sendAndConfirm({ purchaseId, commitment, state: 'pending', updatedAt: Date.now(), ...prepared });
  }

  private confirmed(signature: string, firstConfirmation: boolean): RiteOutcome {
    return { status: 'confirmed', signature, joules: this.joules, firstConfirmation };
  }

  private async sendAndConfirm(rec: RiteRecord): Promise<RiteOutcome> {
    const deadline = Date.now() + this.timeoutMs;
    for (let attempt = 0; Date.now() < deadline; attempt++) {
      // Resending the same signed bytes is safe: the chain applies it at most once.
      if (attempt % 3 === 0) {
        try {
          await this.chain.send(rec.rawTx);
        } catch (e) {
          if (e instanceof RiteRejected) {
            this.ledger.mark(rec.purchaseId, rec.signature, 'failed');
            return { status: 'failed', reason: e.message };
          }
          // Network trouble: keep checking; the burn may still have landed.
        }
      }
      const status = await this.chain.status(rec.signature);
      if (status === 'confirmed') {
        this.ledger.mark(rec.purchaseId, rec.signature, 'done');
        return this.confirmed(rec.signature, true);
      }
      if (status === 'failed') {
        this.ledger.mark(rec.purchaseId, rec.signature, 'failed');
        return { status: 'failed', reason: 'The burn failed on-chain' };
      }
      if ((await this.chain.blockHeight()) > rec.lastValidBlockHeight) break;
      await new Promise((r) => setTimeout(r, this.pollMs));
    }
    // Not confirmed in time. The ledger keeps the burn, and the next request
    // for this purchase checks it before doing anything else.
    return { status: 'pending', signature: rec.signature };
  }
}

/** The real chain: Token-2022 BurnChecked plus a signed memo, from the treasury. */
export class SolanaRiteChain implements RiteChain {
  readonly treasuryAccount: PublicKey;
  private mintChecked: Promise<void> | null = null;

  constructor(
    private readonly connection: Connection,
    private readonly treasury: Keypair,
    readonly mint: PublicKey
  ) {
    this.treasuryAccount = getAssociatedTokenAddressSync(mint, treasury.publicKey, false, JOULE_PROGRAM_ID);
  }

  /** Refuses to burn from anything but a proper Joule mint (checked once). */
  private checkMint(): Promise<void> {
    this.mintChecked ??= getMint(this.connection, this.mint, 'confirmed', JOULE_PROGRAM_ID).then((info) => {
      const problem = jouleMintProblem(info);
      if (problem) throw new Error(`Refusing to burn: ${problem}`);
    });
    // A failed check (e.g. an RPC outage) is retried on the next rite.
    return this.mintChecked.catch((e) => {
      this.mintChecked = null;
      throw e;
    });
  }

  async prepareBurn(memo: string, joules: number): Promise<PreparedBurn> {
    await this.checkMint();
    const { blockhash, lastValidBlockHeight } = await this.connection.getLatestBlockhash('confirmed');
    const tx = new Transaction({ feePayer: this.treasury.publicKey, blockhash, lastValidBlockHeight }).add(
      createBurnCheckedInstruction(
        this.treasuryAccount,
        this.mint,
        this.treasury.publicKey,
        joules,
        JOULE_DECIMALS,
        [],
        JOULE_PROGRAM_ID
      ),
      createMemoInstruction(memo, this.treasury.publicKey)
    );
    tx.sign(this.treasury);
    return {
      signature: base58(tx.signature!),
      rawTx: tx.serialize().toString('base64'),
      lastValidBlockHeight,
    };
  }

  async send(rawTx: string): Promise<void> {
    try {
      await this.connection.sendRawTransaction(Buffer.from(rawTx, 'base64'), { preflightCommitment: 'confirmed' });
    } catch (e) {
      if (e instanceof SendTransactionError) throw new RiteRejected(e.message);
      throw e;
    }
  }

  async status(signature: string): Promise<'confirmed' | 'failed' | 'unknown'> {
    const { value } = await this.connection.getSignatureStatuses([signature], { searchTransactionHistory: true });
    const s = value[0];
    if (!s) return 'unknown';
    if (s.err) return 'failed';
    return s.confirmationStatus === 'confirmed' || s.confirmationStatus === 'finalized' ? 'confirmed' : 'unknown';
  }

  blockHeight(): Promise<number> {
    return this.connection.getBlockHeight('confirmed');
  }
}
