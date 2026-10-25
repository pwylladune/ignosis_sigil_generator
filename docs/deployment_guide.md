# IGNOSIS: End-to-End Release & Deployment Guide

This guide details every component built and provides the exact commands to transition from local development to Solana Mainnet, Apple App Store, and Google Play.

---

> [!WARNING]
> **Status as of 2026-10-25: much of this guide describes simulated features.** v1.0 ships with
> **no token** (`kEnableChain = false`). The backend relay, treasury dispenser, `$IGNOSIS` mint,
> Anchor program and portal described below are not production-ready, and several of them report
> success without doing anything. See [`TASK.md`](../TASK.md) §2 for the findings and the v1.1
> non-custodial direction. Sections marked **⚠ Simulated** must not be followed for a release.

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

> **⚠ Simulated.** The relay's receipt validation, treasury transfer and Pyre stats are mocks (TASK.md C5, C6, C9). Not used by v1.0.

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

> **⚠ Deferred.** No token until there is a legal opinion (TASK.md §2.4, option C). The mint hard-coded elsewhere in the repo, `7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU`, is **Samoyed Coin (SAMO)**, a third-party token (verified on mainnet 2026-10-25). Do not wire it to anything.

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

> **⚠ Does not build.** `declare_id!` is not valid base58 (confirmed with `cargo check`: "failed to decode base58 string"), there is no `initialize`, and it pins Anchor 0.29. v1.1 needs no custom program (SPL Memo).

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

> **Partly current.** Skin products are real. The Ignition Starter Pack (IAP that dispenses a crypto token) is removed from v1.0: it is high-risk under App Store / Play policy (TASK.md §2.3).

App ID on both stores: **`net.ignosis.studio`** (iOS bundle ID and Android `applicationId`; permanent once published).

Configure these identical non-consumable Product IDs in **App Store Connect** and **Google Play Console** (prices are set there; the app only ever displays the store's localised price):

| Product ID | Type | Price | Description |
|---|---|---|---|
| `net.ignosis.studio.skin.all_bundle` | Non-Consumable | $3.99 | Unlocks all 7 premium skins |
| `net.ignosis.studio.skin.tech_occult` | Non-Consumable | $0.99 | Tech-Occult skin |
| `net.ignosis.studio.skin.dark_academia` | Non-Consumable | $0.99 | Dark Academia skin |
| `net.ignosis.studio.skin.cosmic` | Non-Consumable | $0.99 | Cosmic skin |
| `net.ignosis.studio.skin.surrealist` | Non-Consumable | $0.99 | Surrealist skin |
| `net.ignosis.studio.skin.alchemical` | Non-Consumable | $0.99 | Alchemical skin |
| `net.ignosis.studio.skin.wiccan` | Non-Consumable | $0.99 | Greenwood skin (product key kept as `wiccan`) |
| `net.ignosis.studio.skin.chaos` | Non-Consumable | $0.99 | Chaos skin |

The crypto starter pack (`com.ignosis.pack.ignition_279`) is discontinued and must not be created.

---

## 6. Web Portal & Jupiter DEX Integration

> **⚠ Simulated.** The portal's wallet connect is a boolean toggle, stats are seeded, and the Jupiter link points at the third-party SAMO mint.

The React portal is located in `portal/`:

```bash
cd portal
npm run build
```
The static bundle in `portal/dist` can be hosted on **Vercel**, **Cloudflare Pages**, or **Firebase Hosting**. Practitioners can connect their Phantom/Solflare wallets directly and swap SOL for `$IGNOSIS` via Jupiter routing.
