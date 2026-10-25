export interface BurnEvent {
  signature: string;
  practitioner: string;
  amount: number;
  intentHashHex: string;
  timestamp: number;
  source: 'mobile_app' | 'web_portal' | 'on_chain_solana';
}

export interface PyreGlobalStats {
  totalBurned: number;
  totalBurnEvents: number;
  lastBurnTimestamp: number;
  heatJoulesReleased: string;
  activePractitioners24h: number;
}

export class PyreIndexerService {
  // Starts empty: stats come only from recorded events, never seeded numbers.
  private totalBurned: number = 0;
  private totalBurnEvents: number = 0;
  private lastBurnTimestamp: number = 0;
  private recentBurns: BurnEvent[] = [];

  public recordBurn(event: BurnEvent): PyreGlobalStats {
    this.totalBurned += event.amount;
    this.totalBurnEvents += 1;
    this.lastBurnTimestamp = event.timestamp || Date.now();

    this.recentBurns.unshift(event);
    if (this.recentBurns.length > 50) {
      this.recentBurns.pop();
    }

    return this.getStats();
  }

  public getStats(): PyreGlobalStats {
    // Alchemical thermodynamic equivalence: 9.3 x 10^4 Joules per $IGNOSIS
    const joules = this.totalBurned * 93000;
    const exponent = joules > 0 ? Math.floor(Math.log10(joules)) : 0;
    const mantissa = joules > 0 ? (joules / Math.pow(10, exponent)).toFixed(2) : '0.00';
    const dayAgo = Date.now() - 24 * 60 * 60 * 1000;
    const active = new Set(this.recentBurns.filter((b) => b.timestamp >= dayAgo).map((b) => b.practitioner));

    return {
      totalBurned: this.totalBurned,
      totalBurnEvents: this.totalBurnEvents,
      lastBurnTimestamp: this.lastBurnTimestamp,
      heatJoulesReleased: `${mantissa} × 10^${exponent} J`,
      // Lower bound: counted from the in-memory recent window only.
      activePractitioners24h: active.size,
    };
  }

  public getRecentBurns(limit: number = 20): BurnEvent[] {
    return this.recentBurns.slice(0, limit);
  }
}
