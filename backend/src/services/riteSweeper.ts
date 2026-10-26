import { RiteBurnService, RiteOutcome } from './riteBurn.js';
import { RiteLedger } from './riteLedger.js';

export interface RiteSweeperOptions {
  intervalMs?: number;
  /** Leave rites alone while a request may still be working on them. */
  minAgeMs?: number;
  /** Called for each burn the sweeper confirms first. */
  onConfirmed?: (purchaseId: string, commitment: string, outcome: Extract<RiteOutcome, { status: 'confirmed' }>) => void;
}

/**
 * Finishes paid rites that no client came back for: every rite in the ledger
 * that is not yet confirmed is driven through the same fulfilment as a
 * request (resend while it can land, check, rebuild only once it cannot), so
 * a paid burn completes even if the payer closed the app.
 */
export class RiteSweeper {
  private timer: NodeJS.Timeout | null = null;
  private running = false;
  private readonly intervalMs: number;
  private readonly minAgeMs: number;
  private onConfirmed: RiteSweeperOptions['onConfirmed'];

  constructor(
    private readonly burns: RiteBurnService,
    private readonly ledger: RiteLedger,
    options: RiteSweeperOptions = {}
  ) {
    this.intervalMs = options.intervalMs ?? 30_000;
    this.minAgeMs = options.minAgeMs ?? 60_000;
    this.onConfirmed = options.onConfirmed;
  }

  setOnConfirmed(callback: RiteSweeperOptions['onConfirmed']): void {
    this.onConfirmed = callback;
  }

  start(): void {
    if (this.timer) return;
    this.timer = setInterval(() => void this.runOnce(), this.intervalMs);
    this.timer.unref();
  }

  stop(): void {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  /** One pass. Overlapping passes are skipped rather than run twice. */
  async runOnce(): Promise<{ checked: number; confirmed: number; failed: number }> {
    const result = { checked: 0, confirmed: 0, failed: 0 };
    if (this.running) return result;
    this.running = true;
    try {
      for (const { purchaseId, commitment } of this.ledger.unfinished(this.minAgeMs)) {
        result.checked++;
        const outcome = await this.burns.fulfil(purchaseId, commitment).catch(
          (e: Error): RiteOutcome => ({ status: 'failed', reason: e.message })
        );
        if (outcome.status === 'confirmed') {
          result.confirmed++;
          if (outcome.firstConfirmation) this.onConfirmed?.(purchaseId, commitment, outcome);
        } else if (outcome.status === 'failed') {
          result.failed++;
          console.error(`[sweeper] ${purchaseId}: ${outcome.reason}`);
        }
      }
    } finally {
      this.running = false;
    }
    return result;
  }
}
