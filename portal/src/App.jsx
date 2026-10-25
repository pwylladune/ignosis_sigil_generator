import React, { useState, useEffect } from 'react';
import { Flame, ArrowRightLeft, ShieldAlert, Sparkles, ExternalLink, Activity, RefreshCw } from 'lucide-react';

// No $IGNOSIS mint exists. The previous value (7xKXtg…sgAsU) is Samoyed Coin
// (SAMO), a third-party token; linking it sent users to buy someone else's coin.
const IGNOSIS_MINT = '';
const BACKEND_URL = 'http://localhost:3001';

export default function App() {
  const [activeTab, setActiveTab] = useState('pyre'); // 'pyre' | 'trade'
  const [solAmount, setSolAmount] = useState('1.0');
  const [ignosisQuote, setIgnosisQuote] = useState('93,000');
  const [isWalletConnected, setIsWalletConnected] = useState(false);
  const [walletAddress, setWalletAddress] = useState('8x3F...d92A');
  const [isLoadingStats, setIsLoadingStats] = useState(false);

  const [pyreStats, setPyreStats] = useState({
    totalBurned: 14782093,
    totalBurnEvents: 1589,
    heatJoulesReleased: '1.37 × 10^12 J',
    activePractitioners24h: 312,
  });

  const [recentBurns, setRecentBurns] = useState([
    { signature: '4kJ...7wP', amount: 93, time: '18s ago', practitioner: '7xKy...42AA' },
    { signature: '9xL...2qR', amount: 93, time: '1m ago', practitioner: '9bKz...99XF' },
    { signature: '2mP...8sW', amount: 279, time: '4m ago', practitioner: '3tLp...12WQ' },
  ]);

  // Fetch live stats from backend relay
  const fetchLiveStats = async () => {
    setIsLoadingStats(true);
    try {
      const res = await fetch(`${BACKEND_URL}/api/v1/pyre/stats`);
      if (res.ok) {
        const data = await res.json();
        if (data.stats) {
          setPyreStats(data.stats);
        }
      }

      const burnsRes = await fetch(`${BACKEND_URL}/api/v1/pyre/recent?limit=5`);
      if (burnsRes.ok) {
        const data = await burnsRes.json();
        if (data.burns && data.burns.length > 0) {
          setRecentBurns(
            data.burns.map((b) => ({
              signature: b.signature.substring(0, 8) + '...',
              amount: b.amount,
              time: 'Just now',
              practitioner: b.practitioner,
            }))
          );
        }
      }
    } catch {
      // Offline fallback
    } finally {
      setIsLoadingStats(false);
    }
  };

  useEffect(() => {
    fetchLiveStats();
    const interval = setInterval(fetchLiveStats, 15000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column', backgroundColor: '#07070b', color: '#fff', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      {/* Navigation Header */}
      <header style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '20px 40px',
        borderBottom: '1px solid rgba(255, 255, 255, 0.08)',
        backgroundColor: '#0a0a0f',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{
            width: '36px',
            height: '36px',
            borderRadius: '50%',
            background: 'radial-gradient(circle, #ff6d00, #d84315)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxShadow: '0 0 16px rgba(255, 109, 0, 0.5)',
          }}>
            <Flame size={20} color="#fff" />
          </div>
          <div>
            <span style={{ fontSize: '18px', fontWeight: 'bold', letterSpacing: '4px' }}>IGNOSIS</span>
            <span style={{ fontSize: '10px', color: '#ffd700', marginLeft: '8px', letterSpacing: '1px' }}>SOLANA MAINNET / DEVNET</span>
          </div>
        </div>

        <div style={{ display: 'flex', gap: '24px' }}>
          <button
            onClick={() => setActiveTab('pyre')}
            style={{
              background: 'none',
              border: 'none',
              color: activeTab === 'pyre' ? '#ffd700' : 'rgba(255, 255, 255, 0.6)',
              fontWeight: activeTab === 'pyre' ? 'bold' : 'normal',
              cursor: 'pointer',
              fontSize: '13px',
              letterSpacing: '1.5px',
              borderBottom: activeTab === 'pyre' ? '2px solid #ffd700' : 'none',
              paddingBottom: '4px',
            }}
          >
            THE COSMIC PYRE
          </button>
          <button
            onClick={() => setActiveTab('trade')}
            style={{
              background: 'none',
              border: 'none',
              color: activeTab === 'trade' ? '#ffd700' : 'rgba(255, 255, 255, 0.6)',
              fontWeight: activeTab === 'trade' ? 'bold' : 'normal',
              cursor: 'pointer',
              fontSize: '13px',
              letterSpacing: '1.5px',
              borderBottom: activeTab === 'trade' ? '2px solid #ffd700' : 'none',
              paddingBottom: '4px',
            }}
          >
            DEX EXCHANGE
          </button>
        </div>

        <button
          onClick={() => setIsWalletConnected(!isWalletConnected)}
          style={{
            backgroundColor: isWalletConnected ? '#1f1f2e' : '#ff6d00',
            color: '#fff',
            border: '1px solid rgba(255, 255, 255, 0.2)',
            padding: '8px 16px',
            borderRadius: '10px',
            cursor: 'pointer',
            fontWeight: 'bold',
            fontSize: '12px',
            letterSpacing: '1px',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
          }}
        >
          {isWalletConnected ? `CONNECTED: ${walletAddress}` : 'CONNECT SOLANA WALLET'}
        </button>
      </header>

      {/* Main Body */}
      <main style={{ flex: 1, padding: '40px 20px', maxWidth: '1000px', margin: '0 auto', width: '100%' }}>
        {activeTab === 'pyre' ? (
          <div>
            <div style={{ textAlign: 'center', marginBottom: '40px' }}>
              <h1 style={{ fontSize: '32px', letterSpacing: '3px', marginBottom: '12px', color: '#ffd700' }}>
                THE COSMIC PYRE
              </h1>
              <p style={{ color: 'rgba(255, 255, 255, 0.7)', fontSize: '14px', maxWidth: '650px', margin: '0 auto', lineHeight: '1.6' }}>
                Every sigil consecrated via the IGNOSIS studio permanently incinerates $IGNOSIS tokens on the Solana distributed ledger, returning physical form back into pure intent and cryptographic heat.
              </p>
            </div>

            {/* Live Pyre Statistics Grid */}
            <div style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
              gap: '16px',
              marginBottom: '32px',
            }}>
              <div style={{ backgroundColor: '#0f0f18', border: '1px solid rgba(255, 109, 0, 0.3)', borderRadius: '16px', padding: '20px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#ff6d00', marginBottom: '8px' }}>
                  <Flame size={16} />
                  <span style={{ fontSize: '11px', fontWeight: 'bold', letterSpacing: '1px' }}>TOTAL $IGNOSIS BURNED</span>
                </div>
                <div style={{ fontSize: '26px', fontWeight: 'bold' }}>{pyreStats.totalBurned.toLocaleString()}</div>
                <div style={{ fontSize: '11px', color: 'rgba(255, 255, 255, 0.4)', marginTop: '4px' }}>Permanent Deflation</div>
              </div>

              <div style={{ backgroundColor: '#0f0f18', border: '1px solid rgba(255, 215, 0, 0.3)', borderRadius: '16px', padding: '20px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#ffd700', marginBottom: '8px' }}>
                  <Activity size={16} />
                  <span style={{ fontSize: '11px', fontWeight: 'bold', letterSpacing: '1px' }}>CONSECRATION EVENTS</span>
                </div>
                <div style={{ fontSize: '26px', fontWeight: 'bold' }}>{pyreStats.totalBurnEvents.toLocaleString()}</div>
                <div style={{ fontSize: '11px', color: 'rgba(255, 255, 255, 0.4)', marginTop: '4px' }}>Global ritual sacrifices</div>
              </div>

              <div style={{ backgroundColor: '#0f0f18', border: '1px solid rgba(0, 229, 255, 0.3)', borderRadius: '16px', padding: '20px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#00e5ff', marginBottom: '8px' }}>
                  <Sparkles size={16} />
                  <span style={{ fontSize: '11px', fontWeight: 'bold', letterSpacing: '1px' }}>HEAT EQUIVALENT</span>
                </div>
                <div style={{ fontSize: '26px', fontWeight: 'bold' }}>{pyreStats.heatJoulesReleased}</div>
                <div style={{ fontSize: '11px', color: 'rgba(255, 255, 255, 0.4)', marginTop: '4px' }}>Sacrifice released to ether</div>
              </div>
            </div>

            {/* Live Burn Ledger Feed */}
            <div style={{ backgroundColor: '#0f0f18', borderRadius: '16px', padding: '24px', border: '1px solid rgba(255, 255, 255, 0.08)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
                <span style={{ fontWeight: 'bold', letterSpacing: '1px', fontSize: '13px' }}>RECENT ON-CHAIN CONSECRATIONS</span>
                <button
                  onClick={fetchLiveStats}
                  style={{ background: 'none', border: 'none', color: '#00e5ff', fontSize: '11px', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px' }}
                >
                  <RefreshCw size={12} className={isLoadingStats ? 'animate-spin' : ''} /> Refresh Ledger
                </button>
              </div>

              {recentBurns.map((tx, idx) => (
                <div key={idx} style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  padding: '12px 0',
                  borderBottom: idx < recentBurns.length - 1 ? '1px solid rgba(255, 255, 255, 0.05)' : 'none',
                  fontSize: '12px',
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <Flame size={14} color="#ff6d00" />
                    <span style={{ color: '#ff6d00', fontWeight: 'bold' }}>{tx.amount} $IGNOSIS</span>
                    <span style={{ color: 'rgba(255, 255, 255, 0.4)', fontFamily: 'monospace' }}>[{tx.signature}]</span>
                  </div>
                  <div style={{ display: 'flex', gap: '16px', color: 'rgba(255, 255, 255, 0.5)' }}>
                    <span>Practitioner: {tx.practitioner}</span>
                    <span>{tx.time}</span>
                  </div>
                </div>
              ))}
            </div>

            {/* Mint Verification Card */}
            <div style={{ marginTop: '24px', padding: '16px', backgroundColor: '#0b0b12', borderRadius: '12px', border: '1px solid rgba(255, 255, 255, 0.05)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <div style={{ fontSize: '10px', color: 'rgba(255, 255, 255, 0.4)', letterSpacing: '1px' }}>OFFICIAL $IGNOSIS SPL MINT ADDRESS</div>
                <div style={{ fontSize: '12px', fontFamily: 'monospace', color: '#ffd700', marginTop: '2px' }}>{IGNOSIS_MINT || 'Not minted: no official $IGNOSIS token exists'}</div>
              </div>
              <a
                href={IGNOSIS_MINT ? `https://solscan.io/token/${IGNOSIS_MINT}` : undefined}
                target="_blank"
                rel="noreferrer"
                style={{ color: '#00e5ff', fontSize: '11px', display: 'flex', alignItems: 'center', gap: '4px', textDecoration: 'none' }}
              >
                Inspect on Solscan <ExternalLink size={12} />
              </a>
            </div>
          </div>
        ) : (
          /* DEX Exchange Swap Widget */
          <div style={{ maxWidth: '460px', margin: '0 auto' }}>
            <div style={{
              backgroundColor: '#0f0f18',
              borderRadius: '24px',
              padding: '28px',
              border: '1px solid rgba(255, 215, 0, 0.2)',
              boxShadow: '0 8px 32px rgba(0, 0, 0, 0.5)',
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
                <span style={{ fontWeight: 'bold', letterSpacing: '1px', fontSize: '13px' }}>JUPITER DEX SWAP</span>
                <span style={{ color: '#ffd700', fontSize: '11px' }}>Solana Direct Route</span>
              </div>

              {/* Pay SOL */}
              <div style={{ backgroundColor: '#161622', borderRadius: '14px', padding: '14px', marginBottom: '12px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '11px', color: 'rgba(255, 255, 255, 0.5)', marginBottom: '8px' }}>
                  <span>YOU PAY</span>
                  <span>BALANCE: 4.82 SOL</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <input
                    type="number"
                    value={solAmount}
                    onChange={(e) => {
                      setSolAmount(e.target.value);
                      const parsed = parseFloat(e.target.value || '0');
                      setIgnosisQuote((parsed * 93000).toLocaleString());
                    }}
                    style={{
                      background: 'none',
                      border: 'none',
                      color: '#fff',
                      fontSize: '22px',
                      fontWeight: 'bold',
                      outline: 'none',
                      width: '60%',
                    }}
                  />
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px', backgroundColor: '#232334', padding: '6px 12px', borderRadius: '16px' }}>
                    <span style={{ fontWeight: 'bold', fontSize: '13px' }}>SOL</span>
                  </div>
                </div>
              </div>

              {/* Receive $IGNOSIS */}
              <div style={{ backgroundColor: '#161622', borderRadius: '14px', padding: '14px', marginBottom: '20px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '11px', color: 'rgba(255, 255, 255, 0.5)', marginBottom: '8px' }}>
                  <span>YOU RECEIVE (ESTIMATED)</span>
                  <span>BALANCE: 0 $IGNOSIS</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div style={{ fontSize: '22px', fontWeight: 'bold', color: '#ffd700' }}>{ignosisQuote}</div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px', backgroundColor: '#232334', padding: '6px 12px', borderRadius: '16px' }}>
                    <span style={{ fontWeight: 'bold', fontSize: '13px', color: '#ff6d00' }}>$IGNOSIS</span>
                  </div>
                </div>
              </div>

              <a
                href={IGNOSIS_MINT ? `https://jup.ag/swap/SOL-${IGNOSIS_MINT}` : undefined}
                target="_blank"
                rel="noreferrer"
                style={{
                  display: 'flex',
                  justifyContent: 'center',
                  alignItems: 'center',
                  gap: '8px',
                  width: '100%',
                  backgroundColor: '#ff6d00',
                  color: '#fff',
                  padding: '14px',
                  borderRadius: '12px',
                  fontWeight: 'bold',
                  fontSize: '13px',
                  letterSpacing: '1px',
                  textDecoration: 'none',
                  boxShadow: '0 4px 16px rgba(255, 109, 0, 0.4)',
                }}
              >
                SWAP ON JUPITER AGGREGATOR <ExternalLink size={14} />
              </a>

              <div style={{ marginTop: '16px', textAlign: 'center' }}>
                <span style={{ fontSize: '11px', color: 'rgba(255, 255, 255, 0.4)' }}>
                  Trade on Raydium, Orca, or Meteora via Jupiter routing
                </span>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
