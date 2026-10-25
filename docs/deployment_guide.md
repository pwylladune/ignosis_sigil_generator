# IGNOSIS: End-to-End Release & Deployment Guide

This guide details every component built and provides the exact commands to transition from local development to Solana Mainnet, Apple App Store, and Google Play.

---

## 1. System Architecture Overview

```
[Practitioner Mobile App (iOS / Android / Web)]
       │
       ├── In-App Purchases ($0.99 Skins / $1.99 Starter Pack)
       ▼
┌────────────────────────────────────────────────────────┐
│             IGNOSIS RELAY SERVER (Backend)             │
│  - Port 3001 | TypeScript + Express + Helmet           │
│  - Validates StoreKit 2 & Google Play Receipts         │
│  - Automated Solana Treasury Keypair Dispenser         │
│  - Dispatches 279 $IGNOSIS -> User Hardware Enclave    │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
                  [Solana Blockchain]
                  - SPL Token Mint: $IGNOSIS (9 Decimals)
                  - Program ID: Ignos1s111111111111111111111111111111111111
                  - Instruction: consecrate_burn(amount, intent_hash)
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│           COSMIC PYRE INDEXER & WEB PORTAL             │
│  - Aggregates Global Burned Tokens & Heat Joules       │
│  - Live WebSocket / REST Feed                          │
│  - Jupiter DEX Swap Router                             │
└────────────────────────────────────────────────────────┘
```

---

## 2. Running the Backend Relay Locally

The backend relay is located in `backend/`:

```bash
cd backend
npm install
npm run build
npm start
```

### Endpoints:
- `GET /health` — Service health & uptime.
- `GET /api/v1/pyre/stats` — Live global statistics (`totalBurned`, `burnEvents`, `heatJoulesReleased`).
- `GET /api/v1/pyre/recent` — Recent burn ledger records.
- `POST /api/v1/iap/fulfill-starter-pack` — Validates store receipt and deposits 279 `$IGNOSIS` on Solana.
- `POST /api/v1/pyre/record-burn` — Records consecrated burns.

---

## 3. Minting the `$IGNOSIS` Token on Solana

### Devnet (Free Testing):
```bash
npx ts-node scripts/create_token_mint.ts
```
This script:
1. Connects to Solana Devnet.
2. Creates an SPL Token Mint with 9 decimals.
3. Mints 100,000,000 `$IGNOSIS` tokens to the Treasury Associated Token Account.
4. Outputs the `IGNOSIS_MINT_ADDRESS` and `TREASURY_PRIVATE_KEY` to update in `backend/.env`.

### Mainnet Release:
To mint on Solana Mainnet:
1. Set `SOLANA_RPC_URL=https://api.mainnet-beta.solana.com` and `SOLANA_CLUSTER=mainnet-beta`.
2. Ensure your deployer keypair has ~0.05 SOL for network rent.
3. Run `npx ts-node scripts/create_token_mint.ts`.

---

## 4. Deploying the Anchor Consecration Contract

The smart contract program lives in `contracts/programs/ignosis/src/lib.rs`.

1. **Build the Anchor Program**:
   ```bash
   cd contracts
   anchor build
   ```
2. **Deploy to Solana**:
   ```bash
   anchor deploy --provider.cluster devnet # or mainnet
   ```
3. Update `IGNOSIS_PROGRAM_ID` in `backend/.env` and `lib/src/services/solana_ignosis_bridge.dart` with the deployed program address.

---

## 5. In-App Purchase (IAP) Configuration

Configure these identical Product IDs in **App Store Connect** and **Google Play Console**:

| Product ID | Type | Price | Description |
|---|---|---|---|
| `com.ignosis.pack.ignition_279` | Consumable | $1.99 | Sets up Solana vault + deposits 279 `$IGNOSIS` |
| `com.ignosis.skin.all_bundle` | Non-Consumable | $3.99 | Unlocks all 7 premium esoteric genre skins |
| `com.ignosis.skin.tech_occult` | Non-Consumable | $0.99 | Tech-Occult visual skin |
| `com.ignosis.skin.dark_academia` | Non-Consumable | $0.99 | Dark Academia visual skin |
| `com.ignosis.skin.cosmic` | Non-Consumable | $0.99 | Cosmic visual skin |
| `com.ignosis.skin.surrealist` | Non-Consumable | $0.99 | Surrealist visual skin |
| `com.ignosis.skin.alchemical` | Non-Consumable | $0.99 | Alchemical visual skin |
| `com.ignosis.skin.wiccan` | Non-Consumable | $0.99 | Wiccan visual skin |
| `com.ignosis.skin.chaos` | Non-Consumable | $0.99 | Chaos visual skin |

---

## 6. Web Portal & Jupiter DEX Integration

The React portal is located in `portal/`:

```bash
cd portal
npm run build
```
The static bundle in `portal/dist` can be hosted on **Vercel**, **Cloudflare Pages**, or **Firebase Hosting**. Practitioners can connect their Phantom/Solflare wallets directly and swap SOL for `$IGNOSIS` via Jupiter routing.
