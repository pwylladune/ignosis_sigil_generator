import React, { useState, useEffect } from 'react';
import { Flame, ArrowRightLeft, ShieldAlert, Sparkles, ExternalLink, Activity } from 'lucide-react';

export default function App() {
  const [activeTab, setActiveTab] = useState('pyre'); // 'pyre' | 'trade'
  const [solAmount, setSolAmount] = useState('1.0');
  const [ignosisQuote, setIgnosisQuote] = useState('93,000');
  const [isWalletConnected, setIsWalletConnected] = useState(false);
  const [pyreStats, setPyreStats] = useState({
    totalBurned: 14782093,
    burnEvents: 1589,
    heatJoulesReleased: '1.37 x 10^12',
    lastBurnAgo: '42 seconds ago',
  });

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
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
          <span style={{ fontSize: '20px', fontWeight: 'bold', letterSpacing: '4px' }}>IGNOSIS</span>
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
              fontSize: '14px',
              letterSpacing: '1px',
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
              fontSize: '14px',
              letterSpacing: '1px',
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
            padding: '10px 20px',
            borderRadius: '12px',
            cursor: 'pointer',
            fontWeight: 'bold',
            fontSize: '13px',
            letterSpacing: '1px',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
          }}
        >
          {isWalletConnected ? 'CONNECTED: 8x3F...d92A' : 'CONNECT SOLANA WALLET'}
        </button>
      </header>

      {/* Main Body */}
      <main style={{ flex: 1, padding: '40px', maxWidth: '1000px', margin: '0 auto', width: '100%' }}>
        {activeTab === 'pyre' ? (
          <div>
            <div style={{ textAlign: 'center', marginBottom: '40px' }}>
              <h1 style={{ fontSize: '32px', letterSpacing: '3px', marginBottom: '12px', color: '#ffd700' }}>
                THE COSMIC PYRE
              </h1>
              <p style={{ color: 'rgba(255, 255, 255, 0.7)', fontSize: '15px', maxWidth: '650px', margin: '0 auto' }}>
                Every sigil consecrated via the IGNOSIS studio permanently incinerates $IGNOSIS tokens on the Solana distributed ledger, returning material form back into raw chaos and heat.
              </p>
            </div>

            {/* Live Pyre Statistics Grid */}
            <div style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
              gap: '20px',
              marginBottom: '40px',
            }}>
              <div style={{ backgroundColor: '#0f0f18', border: '1px solid rgba(255, 109, 0, 0.3)', borderRadius: '16px', padding: '24px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#ff6d00', marginBottom: '8px' }}>
                  <Flame size={18} />
                  <span style={{ fontSize: '12px', fontWeight: 'bold', letterSpacing: '1px' }}>TOTAL $IGNOSIS BURNED</span>
                </div>
                <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{pyreStats.totalBurned.toLocaleString()}</div>
                <div style={{ fontSize: '12px', color: 'rgba(255, 255, 255, 0.4)', marginTop: '4px' }}>Deflationary reduction</div>
              </div>

              <div style={{ backgroundColor: '#0f0f18', border: '1px solid rgba(255, 215, 0, 0.3)', borderRadius: '16px', padding: '24px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#ffd700', marginBottom: '8px' }}>
                  <Activity size={18} />
                  <span style={{ fontSize: '12px', fontWeight: 'bold', letterSpacing: '1px' }}>CONSECRATION EVENTS</span>
                </div>
                <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{pyreStats.burnEvents.toLocaleString()}</div>
                <div style={{ fontSize: '12px', color: 'rgba(255, 255, 255, 0.4)', marginTop: '4px' }}>Global ritual count</div>
              </div>

              <div style={{ backgroundColor: '#0f0f18', border: '1px solid rgba(0, 229, 255, 0.3)', borderRadius: '16px', padding: '24px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#00e5ff', marginBottom: '8px' }}>
                  <Sparkles size={18} />
                  <span style={{ fontSize: '12px', fontWeight: 'bold', letterSpacing: '1px' }}>HEAT EQUIVALENT</span>
                </div>
                <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{pyreStats.heatJoulesReleased} J</div>
                <div style={{ fontSize: '12px', color: 'rgba(255, 255, 255, 0.4)', marginTop: '4px' }}>Sacrifice released to ether</div>
              </div>
            </div>

            {/* Live Burn Ledger Feed */}
            <div style={{ backgroundColor: '#0f0f18', borderRadius: '16px', padding: '24px', border: '1px solid rgba(255, 255, 255, 0.08)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
                <span style={{ fontWeight: 'bold', letterSpacing: '1px', fontSize: '14px' }}>RECENT ON-CHAIN CONSECRATIONS</span>
                <span style={{ color: '#00e5ff', fontSize: '12px' }}>● Live Solana WebSocket</span>
              </div>

              {[
                { sig: '4kJ...7wP', amount: '93 $IGNOSIS', time: '18s ago', hash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' },
                { sig: '9xL...2qR', amount: '93 $IGNOSIS', time: '1m ago', hash: '872f987629b3c95977926b42f61a1e35a11c6d3df3ee2273673c880a4242646d' },
                { sig: '2mP...8sW', amount: '279 $IGNOSIS', time: '4m ago', hash: 'd4735e3a265e16eee03f59718b9b5d03019c07d8b6c51f90da3a666eec13ab35' },
              ].map((tx, idx) => (
                <div key={idx} style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  padding: '12px 0',
                  borderBottom: idx < 2 ? '1px solid rgba(255, 255, 255, 0.05)' : 'none',
                  fontSize: '13px',
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <Flame size={14} color="#ff6d00" />
                    <span style={{ color: '#ff6d00', fontWeight: 'bold' }}>{tx.amount}</span>
                    <span style={{ color: 'rgba(255, 255, 255, 0.4)', fontSize: '11px', fontFamily: 'monospace' }}>[{tx.sig}]</span>
                  </div>
                  <span style={{ color: 'rgba(255, 255, 255, 0.4)', fontSize: '12px' }}>{tx.time}</span>
                </div>
              ))}
            </div>
          </div>
        ) : (
          /* DEX Exchange Swap Widget */
          <div style={{ maxWidth: '480px', margin: '0 auto' }}>
            <div style={{
              backgroundColor: '#0f0f18',
              borderRadius: '24px',
              padding: '32px',
              border: '1px solid rgba(255, 215, 0, 0.2)',
              boxShadow: '0 8px 32px rgba(0, 0, 0, 0.5)',
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
                <span style={{ fontWeight: 'bold', letterSpacing: '1px' }}>JUPITER DEX SWAP</span>
                <span style={{ color: '#ffd700', fontSize: '12px' }}>Fastest Solana Route</span>
              </div>

              {/* Pay SOL */}
              <div style={{ backgroundColor: '#161622', borderRadius: '16px', padding: '16px', marginBottom: '12px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12px', color: 'rgba(255, 255, 255, 0.5)', marginBottom: '8px' }}>
                  <span>YOU PAY</span>
                  <span>BALANCE: 4.82 SOL</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <input
                    type="number"
                    value={solAmount}
                    onChange={(e) => {
                      setSolAmount(e.target.value);
                      setIgnosisQuote((parseFloat(e.target.value || 0) * 93000).toLocaleString());
                    }}
                    style={{
                      background: 'none',
                      border: 'none',
                      color: '#fff',
                      fontSize: '24px',
                      fontWeight: 'bold',
                      outline: 'none',
                      width: '60%',
                    }}
                  />
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', backgroundColor: '#232334', padding: '6px 12px', borderRadius: '20px' }}>
                    <span style={{ fontWeight: 'bold', fontSize: '14px' }}>SOL</span>
                  </div>
                </div>
              </div>

              {/* Receive $IGNOSIS */}
              <div style={{ backgroundColor: '#161622', borderRadius: '16px', padding: '16px', marginBottom: '24px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12px', color: 'rgba(255, 255, 255, 0.5)', marginBottom: '8px' }}>
                  <span>YOU RECEIVE (ESTIMATED)</span>
                  <span>BALANCE: 0 $IGNOSIS</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div style={{ fontSize: '24px', fontWeight: 'bold', color: '#ffd700' }}>{ignosisQuote}</div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', backgroundColor: '#232334', padding: '6px 12px', borderRadius: '20px' }}>
                    <span style={{ fontWeight: 'bold', fontSize: '14px', color: '#ff6d00' }}>$IGNOSIS</span>
                  </div>
                </div>
              </div>

              <button
                style={{
                  width: '100%',
                  backgroundColor: '#ff6d00',
                  color: '#fff',
                  border: 'none',
                  padding: '16px',
                  borderRadius: '16px',
                  fontWeight: 'bold',
                  letterSpacing: '1px',
                  cursor: 'pointer',
                  fontSize: '15px',
                  boxShadow: '0 4px 20px rgba(255, 109, 0, 0.4)',
                }}
              >
                SWAP ON SOLANA
              </button>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
