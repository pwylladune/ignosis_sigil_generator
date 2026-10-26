/** Test doubles shared by the backend test scripts. */
import { PreparedBurn, RiteChain, RiteRejected } from './services/riteBurn.js';

/**
 * A chain that applies each signed burn at most once, as Solana does, and can
 * lose sends, reject them, or hide a landed burn from status queries.
 */
export class FakeChain implements RiteChain {
  height = 1000;
  prepared = 0;
  sends = 0;
  /** Burns that took effect: the invariant is one per purchase. */
  burns = new Map<string, number>();
  private landed = new Map<string, 'confirmed' | 'failed'>();
  private expiry = new Map<string, number>();
  dropSends = false;
  rejectSends = false;
  hideStatus = false;

  async prepareBurn(memo: string, joules: number): Promise<PreparedBurn> {
    const signature = `sig${++this.prepared}`;
    this.expiry.set(signature, this.height + 150);
    return { signature, rawTx: JSON.stringify({ signature, memo, joules }), lastValidBlockHeight: this.height + 150 };
  }
  async send(rawTx: string): Promise<void> {
    this.sends++;
    if (this.rejectSends) throw new RiteRejected('simulation failed');
    if (this.dropSends) throw new Error('network');
    const { signature, memo, joules } = JSON.parse(rawTx);
    // An expired blockhash can never land.
    if (this.height > this.expiry.get(signature)!) return;
    if (!this.landed.has(signature)) {
      this.landed.set(signature, 'confirmed');
      this.burns.set(memo, (this.burns.get(memo) ?? 0) + joules);
    }
  }
  async status(signature: string) {
    return this.hideStatus ? 'unknown' : this.landed.get(signature) ?? 'unknown';
  }
  async blockHeight() {
    return this.height;
  }
  totalBurnt() {
    return [...this.burns.values()].reduce((a, b) => a + b, 0);
  }
}
