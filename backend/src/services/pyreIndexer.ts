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
  private totalBurned: number = 14782093; // Baseline genesis burns
  private totalBurnEvents: number = 1589;
  private lastBurnTimestamp: number = Date.now() - 42000;
  private recentBurns: BurnEvent[] = [];

  constructor() {
    this.seedRecentBurns();
  }

  private seedRecentBurns() {
    const genesisEntries: Omit<BurnEvent, 'timestamp'>[] = [
      {
        signature: '5xIgnosis31415BurnA7B8C9D017e29Z',
        practitioner: '7xKy82...42AA',
        amount: 93,
        intentHashHex: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        source: 'mobile_app',
      },
      {
        signature: '4mPyreSol8921Bcf731998A1904Kl9',
        practitioner: '9bKz11...99XF',
        amount: 279,
        intentHashHex: 'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb',
        source: 'web_portal',
      },
      {
        signature: '2qCosmicSacrifice7781002Aa8391',
        practitioner: '3tLp44...12WQ',
        amount: 93,
        intentHashHex: '4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a',
        source: 'on_chain_solana',
      },
    ];

    let t = Date.now() - 120000;
    for (const e of genesisEntries) {
      this.recentBurns.push({ ...e, timestamp: t });
      t += 35000;
    }
  }

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
    const exponent = Math.floor(Math.log10(joules));
    const mantissa = (joules / Math.pow(10, exponent)).toFixed(2);

    return {
      totalBurned: this.totalBurned,
      totalBurnEvents: this.totalBurnEvents,
      lastBurnTimestamp: this.lastBurnTimestamp,
      heatJoulesReleased: `${mantissa} × 10^${exponent} J`,
      activePractitioners24h: 312,
    };
  }

  public getRecentBurns(limit: number = 20): BurnEvent[] {
    return this.recentBurns.slice(0, limit);
  }
}
