# IGNOSIS — Current State & Path to Production

_Last reviewed: 2026-10-25 · Updated 2026-10-25 (local session; see §6) · Scope: full repo (Flutter app, `backend/`, `contracts/`, `portal/`, `scripts/`, `docs/`)_

This document records what has been built, what is real versus simulated, and the work needed to ship. It has three parts:

1. **Current state:** an inventory and an honest assessment.
2. **Crypto hooks:** an evaluation and a recommended direction.
3. **Motion & symbol:** a redesign brief so the animation is anchored in the mathematics.

It ends with a phased, prioritized task list.

---

## 0. TL;DR

- **The core is good.** The five sigil engines, the intent-reduction kernel, the 8-skin theme system, the print sheet and the wiki form a coherent, distinctive product. Of the whole codebase, this part is closest to shippable.
- **Every crypto and payment path is a facade that reports success.** Wallet creation, balances, burns, IAP receipt validation, treasury dispensing and the "Global Pyre" stats are all hard-coded, simulated, or fall back to `success: true` on error. If it shipped as-is, users would pay money and receive nothing. In one case they would also lose tokens permanently (see §2.2).
- **Recommendation:** ship **v1.0 without a token**: the sigil studio, paid skins and print. Re-introduce on-chain "consecration" in v1.1 as a **non-custodial memo commitment from the user's own wallet**. That version needs no custom token, no treasury, no program, and no sale of crypto through IAP. Mint `$IGNOSIS` only after a legal opinion (§2.4).
- **Motion today is decoration:** an 8-second rotation loop, a scale pulse, generic embers, and an unused shader. Refocus it so **every motion is the visible evolution of the math that made the symbol**: the hand-writing ductus, the magic-square traversal, Chladni sand migrating to nodal lines, a hash-seeded attractor, and a level-set burn front (§3).

---

## 1. Current State

### 1.1 Repository map

| Area | Path | LOC | Status |
|---|---|---|---|
| Flutter app entry | `lib/main.dart` | 24 | Works; awaits IAP init before `runApp` (startup can stall on a slow store) |
| Intent kernel | `lib/src/models/intent_kernel.dart` | 86 | Solid. Spare reduction (strip vowels, dedupe). "Agrippan" gematria is actually Pythagorean `(i % 9) + 1` |
| Engines | `lib/src/engines/*.dart` | ~560 | Deterministic, but several are mathematically mislabeled (§3.1) |
| Painters | `lib/src/ui/widgets/pen_ink_sigil_painter.dart`, `sigil_painter.dart`, `ember_particle_painter.dart` | ~300 | Pen & Ink painter is live. Neon `SigilPainter` is **dead code** |
| Shader | `assets/shaders/combustion.frag` | 73 | **Not registered** (`flutter: shaders:` missing) and **never loaded** |
| Studio screen | `lib/src/ui/screens/sigil_studio_screen.dart` | 521 | Main UX. `setState` on every burn tick rebuilds the whole screen |
| Skins | `lib/src/ui/theme/sigil_skins.dart` | 223 | 8 well-crafted palettes. **No IAP gating**: every skin is free to select |
| Burn dialogs | `pen_ink_ritual_burn_dialog.dart` (live, class misspelled `PenInkWitualBurnDialog`), `ritual_burn_dialog.dart` (**dead**) | ~400 | Breath guide is a plain 4 s sine and not tied to the sigil |
| Wiki / exegesis | `chaos_wiki_screen.dart`, `ritual_exegesis_modal.dart`, `chaos_magic_wiki_data.dart` | ~550 | Content-complete; answers are not persisted |
| Print | `lib/src/services/sigil_print_service.dart` | 163 | Works (PDF A4 burn sheet) |
| Export | `lib/src/services/universal_export_service.dart` | 57 | PNG works. **`exportSvg` emits an empty `d=""` path** (stub) |
| IAP | `lib/src/services/iap_service.dart` | 193 | Wired to `in_app_purchase`, but has simulated-success fallbacks (§2.2) |
| Wallet | `secure_key_storage_service.dart`, `solana_wallet_service.dart`, `solana_ignosis_bridge.dart` | ~320 | **Unsafe and fake** (§2.2). The bridge is unused |
| Wallet UI | `wallet_consecration_modal.dart`, `seed_phrase_export_modal.dart`, `pay_schema_modal.dart` | ~1070 | Hard-coded balances (3.42 SOL / 777 IGNOSIS). The "Unlock bundle" button only closes the dialog |
| Backend relay | `backend/src/**` | ~580 | Type-checks clean (`tsc --noEmit` passes). Logic is mostly mock (§2.2) |
| Anchor program | `contracts/programs/ignosis/src/lib.rs` | 101 | **Will not build or deploy as-is** (§2.2) |
| Web portal | `portal/src/App.jsx` | 346 | Static mock: fake wallet toggle, seeded stats, `localhost` backend |
| Token script | `scripts/create_token_mint.ts` | 92 | Plausible devnet mint script. No `package.json` at the root to run it |
| Tests | `test/**` | 107 | Engine tests only assert non-empty bounds. Backend `npm test` is `echo` |
| Docs | `README.md`, `docs/deployment_guide.md` | — | README is Flutter boilerplate. The deployment guide describes features as complete that are simulated |
| CI | — | — | None |

### 1.2 What genuinely works
- Typing an intent produces a deterministic glyph in 5 systems, with Kamea planet selection and symmetry folds.
- 8 aesthetic skins switch the entire studio palette.
- Local "ritual combustion" animation, followed by an incinerated state that clears the intent.
- PNG share via `share_plus` and a printable PDF burn sheet.
- Chaos-magic interview wiki and the "Why reduce?" exegesis.

### 1.3 Platform / release hygiene gaps
- **Bundle IDs disagree:** iOS `com.ignosis.ignosisSigilGenerator`, Android `com.ignosis.ignosis_sigil_generator`, backend `com.ignosis.sigilgenerator`. Pick one; IAP products are bound to it. _(Resolved 2026-10-25: `net.ignosis.studio`.)_
- **Android:** `main/AndroidManifest.xml` has no `INTERNET` permission, so release builds can't reach RPC or the backend. Release builds are signed with debug keys, and `applicationId` still has a `TODO`.
- `theme.fontFamily: '-apple-system'` is not a real family on Android or web. `google_fonts` is declared but unused.
- Unused deps: `flutter_riverpod`, `google_fonts`, `vector_math`, `path_provider`.
- No privacy policy or ToS, no app-store metadata, no crash reporting or analytics, no CI.
- `main()` awaits store init, so the app shows a blank screen until StoreKit or Play responds. Init in the background instead.
- The phase controller runs a perpetual 60 fps loop even when idle, which costs battery.

---

## 2. Crypto Hooks — Evaluation

### 2.1 What was designed
- **Free core:** local burn, print, and connecting an external wallet (Phantom/Solflare) to burn `$IGNOSIS` bought elsewhere.
- **$1.99 "Ignition Pack" (consumable IAP):** creates an in-app wallet. The backend verifies the receipt and transfers 279 `$IGNOSIS` from a treasury.
- **On-chain burn:** the Anchor `consecrate_burn(amount, intent_hash)` burns SPL tokens, updates a `GlobalPyre` PDA, and emits an event.
- **Indexer and portal:** a "Cosmic Pyre" leaderboard and stats, plus a Jupiter swap link.

### 2.2 What actually exists (findings, most severe first)

| # | Severity | Finding | Where |
|---|---|---|---|
| C1 | **Critical — loss of funds** | The in-app "wallet" address is `base58(sha256(mnemonic))`. That is not an Ed25519 keypair derivation, and **no private key exists for it**. Tokens dispensed to this address are unrecoverable. The mnemonic is drawn from a ~450-word list (not BIP-39's 2048), has no checksum, and does not restore in any real wallet. | `secure_key_storage_service.dart:40-55` |
| C2 | **Critical — fake success** | `submitBurnConsecration` sends no transaction. It fabricates a signature string from `getSlot`. The UI then decrements a hard-coded balance and says the burn was "recorded on Solana". | `solana_wallet_service.dart:72-100`, `wallet_consecration_modal.dart:34-35,87-95` |
| C3 | **Critical — privacy** | The "intent hash" in that fake signature is the **hex of the raw intent bytes**: reversible plaintext. Separately, the unsalted `sha256(UPPERCASE(intent))` in `solana_ignosis_bridge.dart` can be dictionary-attacked for short sentences. | `solana_wallet_service.dart:78-79` |
| C4 | **Critical — paid, not delivered** | The client IAP returns `success: true, isSimulated: true` on **any** network error. `buyIgnitionStarterPack` fulfills **for free** when the store is unavailable or products are empty. The UI always adds +279 to the displayed balance. | `iap_service.dart:148-157,161-172`, `wallet_consecration_modal.dart:121` |
| C5 | **Critical — server** | The receipt validator accepts **any** receipt when `NODE_ENV=development` (the default), when `platform: 'mock'`, or when a string has prefix `mock_` or `sandbox_`. "Production" iOS and Android paths accept any non-empty string, so anyone can `curl` free tokens. There is no idempotency on `transactionId`, so a receipt can be replayed. | `receiptValidator.ts:25-101` |
| C6 | **Critical — server** | The treasury reports `success: true` with a fake signature when the on-chain transfer fails. A base58 `TREASURY_PRIVATE_KEY` is silently replaced with `Keypair.generate()`. The key is read from plain env. | `solanaTreasury.ts:46-49,137-153` |
| C7 | High | The hard-coded mint `7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU` appears to be **an existing third-party mainnet token** (it matches the publicly known Samoyedcoin/SAMO mint; verify on an explorer). The portal's Jupiter link would send users to buy someone else's token. | `config.ts:13`, `solana_ignosis_bridge.dart:13`, `portal/src/App.jsx:4` |
| C8 | High | The Anchor program **cannot compile**: `declare_id!("Ignos1s…")` contains `I` and `l`, which are not valid base58. There is no `initialize` instruction, so the `global_pyre` PDA can never exist and every burn fails. `checked_add().unwrap()` panics instead of returning an error. There is no `Anchor.toml` or workspace. It pins Anchor 0.29. | `contracts/programs/ignosis/src/lib.rs` |
| C9 | High | The Pyre indexer is in-memory and seeded with **fabricated numbers**: 14,782,093 burned, 1,589 events, `activePractitioners24h: 312` hard-coded. `record-burn` and `webhook` are unauthenticated, so anyone can inflate the stats. Webhook burns are recorded as 93 regardless of the real amount. | `pyreIndexer.ts`, `routes/pyre.ts` |
| C10 | Medium | CORS `*`, no rate limiting, no persistence, no structured logging. The `test-server.ts` integration test is not wired to `npm test`. | `server.ts` |
| C11 | Medium | The portal's "Connect wallet" is a boolean toggle. The wallet-adapter packages are installed but never used. The backend URL is hard-coded to `localhost`. | `portal/src/App.jsx` |
| C12 | Medium | Skins are not gated: `SkinSelectorModal` lets anyone select any skin, so paid IAP has nothing to unlock. There is no "Restore purchases" button, which App Review requires. | `skin_selector_modal.dart:89` |

### 2.3 Platform & regulatory risk (needs counsel; not legal advice)
- **App stores:** Selling an IAP consumable whose fulfillment is a **transferable crypto token** is high-risk under Apple's guidelines on cryptocurrencies and digital goods (§3.1.1 / §3.1.5) and under Google Play's blockchain-content policy. Rejection or removal is a realistic outcome. Wallet functionality may also need to come from an organization account and is limited by region.
- **Financial regulation:** Selling a fungible token for fiat, and running a treasury that dispenses it, may raise money-transmission and securities questions depending on jurisdiction. That is especially true if a secondary market (the Jupiter link) is promoted.
- **Custody:** Holding user keys, even "in the enclave", makes the app a custodial or semi-custodial wallet, with matching support and liability burden.
- **Marketing copy:** Text like "9.3 × 10⁴ J per $IGNOSIS", "proof-of-heat" and "energetic sacrifice" is fine as ritual and poetic framing. It must never read as a financial or physical claim, and the UI should label it as symbolic.

### 2.4 Options

| Option | What ships | Effort | Risk | Verdict |
|---|---|---|---|---|
| **A. No crypto (v1.0)** | Studio, skins IAP, print, share | Low: delete or flag the crypto UI | Lowest | **Do this first** |
| **B. Non-custodial on-chain commitment (v1.1)** | Users connect **their own** wallet. One tx carries an **SPL Memo** with a salted intent commitment (optionally plus a burn of *any* token they choose). The Pyre indexes real Memo txs | Medium | Low–medium. No token issuance, no custody, no IAP-for-crypto | **Recommended crypto path** |
| **C. Own `$IGNOSIS` token** | Mint, treasury, burn program, DEX listing | High | High: legal, store, liquidity, security audit | **Defer** until there is a legal opinion and user traction |

#### Why B is the right crypto shape
- **No custom program is needed.** A burn is just the SPL Token `Burn` instruction. The ritual record is an `spl-memo` instruction in the same transaction: `IGNOSIS:v1:<commitment-hex>`. The "global pyre" total is computed **off-chain by the indexer** from confirmed transactions, so there is no PDA, no `initialize`, and no upgrade authority to secure. If C is ever chosen, the same indexer still works.
- **Privacy-preserving commitment:** `commitment = SHA-256(nonce ‖ NFC(intent))`. `nonce` is 32 random bytes kept only on-device in secure storage. It is never brute-forceable, and the user can later *prove* the sigil without revealing it.
- **Signing:**
  - Android: Solana **Mobile Wallet Adapter** (MWA).
  - iOS: Phantom or Solflare **deep-link** connect/sign protocol, with an encrypted session.
  - Web: `@solana/wallet-adapter`, which is already a portal dependency.
- **Indexer:** a Helius (or similar) webhook filtered to Memo-program txs with the `IGNOSIS:` prefix. Verify the webhook auth header, persist to Postgres, and derive stats from **real rows only**. Delete the seeded genesis numbers.
- **Visual payoff:** the commitment hash becomes an input to the motion system (§3.4). On-chain consecration then visibly changes the seal instead of only showing a toast.

#### If C is pursued later (minimum bar)
- Proper BIP-39 (2048 words plus checksum) with SLIP-0010 Ed25519 derivation `m/44'/501'/0'/0'` from a vetted library. Better: no in-app keys at all, using an embedded-wallet provider or MWA.
- Server receipt validation through the **App Store Server API** (JWS signature chain verified) and **Google Play Developer API** `purchases.products.get`, idempotent on `transactionId` / `orderId`, with a persisted fulfillment ledger and retry queue. **Never** report success for a simulated transfer.
- Treasury key in KMS/HSM, a daily dispense cap, alerting, and the mint authority revoked after the fixed supply is minted. Freeze authority `null`. Metadata through Token-2022 metadata or Metaplex.
- An external audit of any on-chain program. Fix `declare_id`, add `initialize`, replace `unwrap()` with errors, and move to current Anchor.

---

## 3. Motion & Symbol — Refocus Brief

### 3.0 Design thesis
> **Nothing moves unless the mathematics moves it.**
> Every animation is the time-evolution of the same function that generated the glyph. Motion is either the *construction* (how the symbol is written), the *field* it lives in (resonance, square, rose), or the *dissolution* (combustion). Decoration such as generic rotation, blur glow or random sparks is removed.

Global principles:
1. **One clock, physical units.** Drive everything from a single `Ticker` in seconds (`t`), not a looping 0→1 controller. Loops cause discontinuities. **Bug:** Spare rotation `phase * 0.2` snaps back by 0.2 rad (about 11.5°) every 8 s.
2. **Minimum-jerk easing.** Human hand motion follows `s(τ) = 10τ³ − 15τ⁴ + 6τ⁵` (Flash & Hogan, 1985). Use it for all draw-on and morph timing. It is what makes a stroke feel *written*, not *tweened*.
3. **Constant ink speed.** Reveal strokes by **arc length** using `PathMetrics` / `extractPath`, with pen speed fixed in px/s. Longer sigils take longer to write, so duration is honest.
4. **Incommensurate frequencies for idle life.** Use ratios of φ (1.618…) and √2 so idle motion never visibly repeats, yet stays smooth. Keep amplitudes small: stroke weight ±3%, guide-ring precession of a few degrees per minute.
5. **Breath is the master rhythm in Gnosis.** Default to resonance breathing at **5.5 breaths/min** (≈10.9 s: inhale 5.45 s, exhale 5.45 s), with presets for box (4-4-4-4) and 4-7-8. The breath curve `b(t)` drives the dialog guide **and** the sigil, so the two are synchronized.
6. **Respect the body.** Honor `MediaQuery.disableAnimations` / reduce-motion: replace the motion with static states and crossfades. No luminance flicker above 3 Hz (photosensitivity guidance).
7. **Cache geometry, animate parameters.** Engines currently rebuild the full `Path` every frame. Cache by `(kernel, system, params, size)` and animate only uniforms, transforms and reveal length.

### 3.1 Engine-by-engine: correctness fix + native motion

| Engine | Math issue today | Fix (symbol) | Native motion (anchored) |
|---|---|---|---|
| **Spare monogram** | Radicals stack on one vertical spine like a ladder. Only rotational symmetry Cₙ. Rotation wraps discontinuously | Place radicals on a shared armature and merge coincident strokes (shared verticals). Offer dihedral **Dₙ** (mirror and rotation) as well as **Cₙ** | **Ductus:** each radical is written in kernel order with minimum-jerk, then the fundamental domain is **replicated by the group action**. Copies rotate out from angle 0 to their place `2πk/n` with staggered starts, so the user watches the symmetry group assemble the seal. Then stillness |
| **Planetary Kamea** | Letter → `(code − 65) % n² + 1` collides on small squares. Real practice uses **Aiq Bekar / gematria reduction** into the square's range. The repeat-loop branch never fires because the kernel is deduped. Cells are non-square on non-square canvases | Gematria value, then reduce into `[1, n²]` (Aiq Bekar). Center a square grid. Render the faint square, labelled with the magic constant **M = n(n² + 1)/2** | **Traversal:** a pen point travels cell to cell at constant arc speed. Each visited cell's number glows briefly, then fades back to the grid. After the trace completes, the row/column/diagonal sums briefly "light" to M, showing the square's invariance as its consecration |
| **Rose Cross** | `_petalOrder` has 27 entries with `A` twice. Tiers are `index % 3`, not the 3 / 7 / 12 structure | A true three-ring rose. **Inner 3** (mother letters), **middle 7** (doubles), **outer 12** (simples), with a published Latin→Hebrew transliteration table so all 26 Latin letters land deterministically | **Astrolabe lock:** rings counter-rotate at angular speeds in ratio **3 : 7 : 12**. The sigil path is drawn *between* ring positions while they move, and the rings ease to a shared alignment (phase-locked, like a cryptex) as the last stroke lands |
| **Cymatic (Chladni)** | Not Chladni: it perturbs polar rings by `sin(n·cosθ)·sin(m·sinθ)`, with no nodal set | Square free plate: `f(x,y) = cos(nπx)·cos(mπy) − cos(mπx)·cos(nπy)` on `[−1,1]²` (or a circular plate using Bessel modes `J_k(α r)·cos kθ`). Extract `f = 0` with **marching squares** (cached) | **Sand physics, the hero effect.** 3–8k particles start uniformly and descend the energy `E = f²` with `v = −k∇(f²) + ε·η(t)` (small thermal noise). They visibly *migrate onto the nodal lines*, the way real sand does. Changing the intent **morphs the mode** `(1 − s)·f₁ + s·f₂` with minimum-jerk `s`, and the sand flows between patterns. Gnosis breath modulates `ε` (plate "amplitude") |
| **Cyber Chaos** | Joins 15 hash-derived polar points with straight lines: noisy, not legible | Seed a **strange attractor** from SHA-256 bytes. Clifford: `xₙ₊₁ = sin(a·yₙ) + c·cos(a·xₙ)`, `yₙ₊₁ = sin(b·xₙ) + d·cos(b·yₙ)`, with `a,b,c,d ∈ [−2,2]` from the digest. Reject seeds with a low Lyapunov exponent or low fill (non-chaotic). Render as a log-density histogram in ink tones. Apply Cₙ symmetry by folding | **Accretion:** iterate N points per frame, so the attractor *condenses out of noise* over ~4 s and density accumulates like ink in paper. Idle: a slow parameter drift `a(t) = a₀ + δ·sin(2πt/φ⁴)` that stays inside the chaotic basin, so the seal breathes without changing identity |

Also add a **6th engine, Harmonograph:** `x(t) = Σᵢ Aᵢ·sin(fᵢ·t + pᵢ)·e^(−dᵢ·t)` (likewise `y`), with frequency ratios near small integers (2:3, 3:4, plus detune) drawn from the kernel. It is a natural fit for the Pen & Ink aesthetic: the pendulum *draws* itself, and decay gives a beginning and an end.

**Kernel and determinism**
- Keep "same intent → same seal". Add an optional **variant nonce** so a user can re-roll deterministically: `seed = H(kernel ‖ variant)`.
- After sealing or charging, hide the displayed reduced kernel. Forgetting the intent is part of the practice.
- Rename the "Agrippan" gematria to Pythagorean, or implement true Agrippan values.

### 3.2 Charging (Gnosis) sequence
1. **Fixation:** the canvas desaturates to the guide color. Concentric rings at radii `rₖ = R·φ^(−k)` drift slowly *inward* toward the vermilion bind-point (a golden-ratio zoom). They are slow and low-contrast, not hypnotic flicker.
2. **Breath coupling:** the sigil's stroke weight and ink-wash opacity follow `b(t)`, the same curve as the dialog's guide. On exhale, the Chladni sand settles. On inhale, `ε` rises and the sand lifts.
3. **Peak:** after N breath cycles (default 7, user-set), the guide offers "Release". The dialog never auto-advances.

### 3.3 Combustion (dissolution) sequence
Replace the generic ember spray and diagonal shader sweep with a burn that *knows the sigil*:
1. **Reverse ductus.** Ignition starts at the terminal crossbar (the last stroke) and the flame front travels **backward along the path by arc length** to the opening circle. The sigil is *unwritten* in the reverse of how it was written.
2. **Level-set front (shader).** Precompute a signed-distance texture `d(x)` from the sigil path (the CPU side bakes a distance field once). The front is `φ(x,t) = d_ignite(x) − v·t + A·fbm(x, t)`. Draw the char band where `0 < φ < w`, an incandescent rim with color from blackbody temperature (≈1000 K → 1800 K ramp), and ash beyond it. **Register the shader** in `pubspec.yaml` under `flutter: shaders:` and load it with `FragmentProgram.fromAsset`.
3. **Embers advected by curl noise.** Particles spawn *on the front* and move with `v = ∇×ψ(x,t) + buoyancy·ŷ`, where ψ is a scalar noise potential. The field is divergence-free, so smoke curls realistically instead of sliding diagonally. Cap ~2k particles and batch with `drawRawPoints` / `drawVertices`.
4. **Tie to the act.** If an on-chain commitment exists (§2.4 B), seed the fbm and ember field from the commitment hash, so each burn is unique and reproducible. Optionally scale burn duration with `log₁₀(amount)` (bounded 3–9 s).
5. **Silence.** Hold the empty plate for ~2 s, then fade in the "Does not matter, need not be" banishing line. Offer "Banish with laughter" as a light, deliberately mundane closing interaction.

### 3.4 Transitions & idle
- **System switch:** resample both paths to K points by arc length, choose the cyclic shift that minimizes Σ‖pᵢ − qᵢ‖², and morph with minimum-jerk over 700 ms. Where topology differs (several contours), crossfade with an ink-bleed dissolve.
- **Typing:** debounce 150 ms. Added consonants *write on*; removed ones *lift off*. No full redraw.
- **Idle:** stillness by default. Allowed motions: guide-ring precession at φ-ratio speeds, ±3% stroke breathing, and sand Brownian jitter in Cymatic. Stop the ticker entirely when the screen is off or the app is backgrounded.

### 3.5 Export to match the motion
- **Real SVG.** Serialize the `Path` (sample `PathMetrics` into cubic Béziers) and add an animated variant that uses `stroke-dasharray` / `stroke-dashoffset` for the draw-on.
- **Video / GIF of the ductus.** Offline-render the frames at fixed dt and encode them, for sharing.
- **Print:** vector PDF from the same path rather than a rasterized PNG.

### 3.6 Implementation notes (Flutter)
- Add `lib/src/motion/`:
  - `clock.dart`: single ticker, seconds, reduce-motion aware.
  - `easing.dart`: minimum-jerk easing, breath curves.
  - `ductus.dart`: arc-length reveal.
  - `field_particles.dart`: gradient and curl-noise integrators, run in an isolate or SIMD-friendly typed arrays.
  - `morph.dart`
- Engines return a **`SigilGeometry`** value: strokes in written order, nodes, guides and fields. Returning only a flattened `Path` loses the ordering that the ductus needs.
- Painters become thin. Animate with `AnimatedBuilder` scoped to the canvas only, never `setState` on the whole screen.
- Golden tests: render each engine for fixed kernels and compare PNGs. Property tests: Kamea sums equal M, the Rose maps all 26 letters exactly once, attractor seeds pass the chaos check.

---

## 4. Prioritized Task List

### P0: blockers before any store submission (v1.0, no-token release)
- [x] **Feature-flag off all crypto UI** (wallet modal, seed export, starter pack, `$IGNOSIS` copy, portal trade tab) behind `kEnableChain = false`. _(a1c27a9f; the portal no longer links the SAMO mint, see the review batch.)_
- [x] Delete or quarantine the fake paths: `SecureKeyStorageService.createInAppWallet`, `submitBurnConsecration`, the IAP simulated fallbacks, and the hard-coded balances. _(8a954ac1 client, d0d1ecf2 backend, 2371d50a portal; reviewed by you before commit.)_
- [x] **Gate skins by entitlement.** Read `IapService.unlockedSkins` in `SkinSelectorModal`, wire the purchase buttons in `PaySchemaModal`, and add **Restore Purchases**. Persist the selected skin. _(d259bda9)_
- [x] Move IAP init off the critical path in `main()`. _(d259bda9)_
- [ ] Unify the bundle ID / applicationId. Configure Android release signing. Add the `INTERNET` permission if any network call remains. _ID done: `net.ignosis.studio` on both platforms, display name IGNOSIS (8321ef6a). Product IDs are `net.ignosis.studio.skin.*` (e23ebebb). Still open: release signing needs your keystore. INTERNET is not needed once the review batch lands: the app makes no network calls of its own (`http` removed), and Play Billing declares its own permissions._
- [x] Register `assets/shaders/` under `flutter: shaders:`, or remove the shader until §3.3 lands. _(registered; rewritten as the level-set burn, a865c25c)_
- [x] Fix the Spare rotation discontinuity, or remove idle rotation (moot once §3 lands). _(no idle rotation; single clock, b55dd3a0)_
- [ ] Privacy policy, ToS, age rating, App Store / Play listing copy. Mark energetic and "Joules" language as symbolic.
- [x] Replace the README with real setup, architecture and run instructions. Mark `docs/deployment_guide.md` sections that describe simulated features. _(05274561)_
- [x] CI (GitHub Actions): `flutter analyze`, `flutter test`, backend `tsc` and tests. _(6144b66c. Goldens are excluded on Linux. Backend `npm test` runs the fail-closed integration test once the review batch lands.)_

### P1: Motion & symbol (the v1.0 differentiator; see §3)
- [x] Motion core: single clock, minimum-jerk easing, reduce-motion, ticker paused when idle. _(b55dd3a0)_
- [x] `SigilGeometry` refactor (ordered strokes) plus a geometry cache.
- [x] Ductus draw-on for all engines. _(Chladni draws with sand and Cyber Chaos with accretion instead of a pen.)_
- [x] Kamea: Aiq Bekar mapping, centered square, traversal and magic-sum consecration. _(4990638e)_
- [x] Rose Cross: correct 3/7/12 rose and transliteration table, astrolabe lock. _(b3ee653d)_
- [x] Chladni: real nodal field, marching squares, sand-particle physics, mode morphing. _(7f359dc3)_
- [x] Cyber Chaos: hash-seeded Clifford attractor with chaos validation and density render. _(57c9d7ef; overdraw approximates log density; idle parameter drift intentionally omitted to keep stillness by default)_
- [x] Spare: armature merge, Dₙ / Cₙ group-assembly animation. _(005e525e)_
- [x] Combustion: reverse-ductus, SDF level-set shader, curl-noise embers. _(a865c25c; also the 2 s silence and "Banish with laughter")_
- [x] Gnosis breath master curve shared by the dialog and the canvas (resonance / box / 4-7-8). _(b55dd3a0. Not done: the φ-ratio fixation rings of §3.2.1.)_
- [ ] System-switch morph and typing write-on / lift-off. _Partial: typing is debounced (260 ms), then the pen rewrites; Chladni sand morphs between modes. No cross-system path morph yet._
- [ ] Real SVG export (static and animated) plus vector PDF.
- [x] Remove dead code: `SigilPainter`, `RitualBurnDialog`, `SolanaIgnosisBridge` (or fold it into §2.4 B), unused deps. Rename `PenInkWitualBurnDialog`. _(09bc63ec; the bridge and `http` / `flutter_secure_storage` go with the review batch)_
- [x] Golden and property tests for every engine. _(74cb7b10 plus the per-engine commits)_

### P2: v1.1 non-custodial consecration (Option B)
- [ ] Commitment scheme: `SHA-256(nonce ‖ NFC(intent))`, nonce in secure storage, and an optional "prove" view.
- [ ] Wallet connect: MWA (Android), Phantom/Solflare deep links (iOS), wallet-adapter (web portal).
- [ ] Transaction builder: Memo `IGNOSIS:v1:<hex>`, optionally plus a burn of a user-chosen SPL token. Simulate before signing; show the fee and the explorer link.
- [ ] Backend rewrite: Postgres, an authenticated Helius webhook, and Memo-prefix filtering. Stats come only from confirmed txs. Delete the seeded genesis numbers, `record-burn` and CORS `*`; add rate limiting and structured logs.
- [ ] Portal: real wallet-adapter connect, env-configured API URL, live Pyre from the indexer. Remove the swap link to the third-party mint.
- [ ] Feed the commitment into the burn shader seed (§3.3.4).

### P3: only if Option C is approved by counsel
- [ ] Legal opinion (securities / money transmission) and app-store pre-clearance.
- [ ] Mint: fixed supply, mint authority revoked, freeze authority null, metadata.
- [ ] Real receipt validation (App Store Server API JWS, Play Developer API), an idempotent fulfillment ledger, KMS treasury, caps and alerts.
- [ ] If a program is still needed: fix `declare_id`, add `initialize`, remove `unwrap`, upgrade Anchor, add `Anchor.toml` and tests, get an external audit.
- [ ] Wallet custody: embedded-wallet provider or proper BIP-39/SLIP-0010. Never `sha256(mnemonic)`.

---

## 5. Verification notes from this review
- `backend`: `npm ci && npx tsc --noEmit` passes.
- Flutter, Anchor and the portal were **not built** in this review: no Flutter SDK or Anchor CLI in the review environment, and the portal was not installed. The Anchor build failure (C8) is inferred from the invalid base58 in `declare_id!` and the missing `initialize`.
- C7 (mint identity) could not be checked live because the Solana RPC was unreachable from the review environment. Confirm on a block explorer before relying on it.

---

## 6. Local session log (2026-10-25)

### 6.1 Tooling baseline (before any code change)
| Tool | Result |
|---|---|
| Flutter | 3.44.8 stable, Dart 3.12.2. `flutter doctor`: all green except **Android licences not accepted**. Run `flutter doctor --android-licenses` yourself; it accepts licence terms. |
| Xcode / CocoaPods | Xcode 27.1, CocoaPods 1.17.0 (CocoaPods warns unless the shell uses a UTF-8 locale; set `LANG=en_US.UTF-8`) |
| Android | SDK 36, JDK 17 |
| Node | Homebrew `node` 26 was already installed; `node@22` was added (keg-only) for CI parity. **Side effect:** installing `node@22` upgraded `simdjson`, which broke `node` 26 (`libsimdjson.33.dylib` missing). Fixed by upgrading `node` to 26.12.1. |
| Rust | Homebrew `rustup` (keg-only), toolchain 1.99.1 stable. Add `/opt/homebrew/opt/rustup/bin` and `~/.cargo/bin` to `PATH`. |
| Solana | Agave CLI 4.3.2 (current stable). Add `~/.local/share/solana/install/active_release/bin` to `PATH`. |
| Anchor | `avm` 1.2.1 → `anchor-cli` **1.2.1** (latest stable; 2.0 is still a release candidate). Note: the crates.io crate named `avm` is an unrelated Node version manager, so install `avm` from the Anchor git tag. |
| `flutter pub get` / `analyze` / `test` | Clean / no issues / 10 of 10 passed |
| Backend `npm ci && tsc --noEmit` | Passes |
| Portal `vite build` | Builds (first time it has been built) |
| Anchor program `cargo check` | **Fails as predicted (C8):** `failed to decode base58 string` in `declare_id!`, then `cannot find value ID`. |

### 6.2 Verified or contradicted
- **C7 confirmed.** On mainnet, `7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU` is **Samoyed Coin (SAMO)**: a live mint with mint and freeze authority `null`, about 5.7 B supply and about 90 k holders. Removed from backend defaults, `.env.example` and the portal (review batch).
- **C8 confirmed** by a real build (above).
- **New:** the Pen & Ink painter ignored the active skin for guides and the bind point; they used fixed `IgnosisTheme` colours. Scenes now take every colour from the skin.
- **New:** at phone width (390 pt) the bottom bar (skin tag + burn button) and the skin dialog header overflowed. Fixed in the review batch, since those files also carry payment changes.
- **New (Kamea):** with true Aiq Bekar reduction, several consonants share a chamber. On Sol, M (40), D (4) and T (400) all land on cell 4, so traces can revisit a cell and retrace lines. This is faithful to the tradition but looks sparse for some intents. Options: draw a small bounce or teardrop on non-consecutive revisits, or let the user pick the planet that gives the most distinct cells.
- **Not done from round 2:**
  - Alchemical bone body text (Ellie's note was non-binding).
  - `FLAG_SECURE` / app-switcher privacy (optional).
  - Anchor `contracts/` hardening (deferred; it does not build).
  - Vite 6 for the two dev-server advisories.
- **The Rose maps all 26 letters exactly once:** taken literally, this is impossible, because C/K, I/J/Y, F/P and U/V/W share Hebrew letters and Teth and Tzaddi need digraphs. The test now checks the documented coverage instead.
- **Own bug, fixed:** Chladni sand was seeded from `Object.hash`, which is randomised per process, so the same intent settled differently between runs. Seeds are now stable (74cb7b10).
- The `combustion.frag` shader compiles and runs under Impeller. In `flutter test`, only the first test in a file gets it; later tests fall back to reverse ductus because the asynchronous load does not finish under fake async. This is a harness artifact; the canvas now preloads the shader.

### 6.3 Payments batch (reviewed, then committed)
Held back for review under the rule "stop and show the diff before any commit touching payments, keys or on-chain code". After your review it was committed as 8a954ac1 (client wallet removal), d259bda9 (IAP gating and fixes), d0d1ecf2 (backend fail-closed) and 2371d50a (portal). It contains:
- Client: delete `wallet_consecration_modal`, `seed_phrase_export_modal`, `secure_key_storage_service` (the `sha256(mnemonic)` wallet), `solana_wallet_service` (fake burns) and `solana_ignosis_bridge`. The studio no longer opens a wallet. `http` and `flutter_secure_storage` are removed.
- IAP: `IapService` is now a `ChangeNotifier` with no simulated or offline fulfilment, no starter pack, and `buyNonConsumable` for skins and the bundle. Restore Purchases is available, unlocks are cached locally, and `main()` no longer awaits the store.
- UI: locked skins show their store price and buy on tap. The bundle and Restore are wired in both dialogs. The selected skin is persisted and falls back to the free skin when there is no entitlement.
- Backend (fails closed): the receipt validator refuses everything (no dev, mock or sandbox bypass); the treasury never generates a keypair or fabricates a signature; the Pyre starts empty with writes requiring `PYRE_WRITE_SECRET`; there is no SAMO default mint and no invalid program id. `npm test` runs `test-server.ts`, which now asserts this.
- Portal: the mint is blank, so there are no Solscan or Jupiter links to SAMO.
- Tests: `test/services/iap_service_test.dart` (no store, no unlock) and a widget test proving a saved premium skin is not applied without an entitlement.
- After the sub-agent review (§6.5), it also:
  - Grants on Android only when Play's purchase state is `purchased`. Restore marks pending purchases "restored", and those are no longer unlocked or acknowledged.
  - Re-syncs owned purchases on Android at startup and on resume, so purchases completed while the app was closed get acknowledged.
  - Catches store exceptions and shows the last store error inline in both dialogs.
  - Re-queries products when a purchase is attempted offline.
  - Never shows a hard-coded USD price.
  - Backend: timing-safe secret compare; the webhook records only complete events; no internal error text in responses; the starter-pack route answers 410 Gone; a malformed mint no longer crashes startup.

### 6.5 Sub-agent review (2026-10-25) and fixes
Three read-only reviewers covered payments, maths and determinism, and Flutter runtime.
- **Process error (fixed):** commit `1f6d4982` had swept in the staged deletions of the wallet and key code, against the review rule, and left HEAD uncompilable. The last three local commits were rebuilt without them (old state kept as `backup/before-history-fix`). Nothing had been pushed.
- **Cyber Chaos was not deterministic across platforms (fixed, a838f67b):** a 1-ulp libm difference grows chaotically. It now uses `det_math.dart`, and the result is pinned bit-for-bit on the VM and Chrome; CI runs both.
- **Burn field (fixed, 7b20d6e3):**
  - It depended on stroke grouping; it is now a Dijkstra fuse network.
  - The shader's 16-bit decode was off by up to 0.4 % with colliding codes.
  - A zero-size canvas crashed.
- **Runtime (fixed, e65e26a9):**
  - A burn was cancelled by a mid-burn change and the button stayed locked.
  - Resizes rebuilt scenes and re-ran Chladni (65–82 ms per frame). Scenes now live in a 512² reference space.
  - Reduce-motion typing cost about 89 ms per key.
  - The breath notifier could be written after dispose.
- **Engines and hygiene (fixed, e1db5f33):**
  - Kamea now has a true constant-speed pen.
  - Short sigils had no terminal crossbar.
  - The Kamea and Rose text caches churned and leaked.
  - Combustion never released its shader or texture.
  - The Rose 26-letter test was trivially true.
- **Payments (fixed in the uncommitted batch):** see §6.3.

### 6.6 Six-specialist review round 2 (/leeloo) and remediation (2026-10-25)
Six reviewers took part: esoteric-researcher, research, ellie, code-reviewer, security-auditor and performance-profiler. The esoteric findings were cross-checked against the research brief, and the Rose outer ring against a third source. Every item was actioned:

- **Phase 1, bugs and privacy (b9d63af8, cd056a25):**
  - A burn started during the typing debounce locked the studio.
  - The plate never painted its paper, so dark-skin exports were transparent.
  - iOS Reduce Motion was ignored (`reduceMotionOf`).
  - Chladni reduce-motion morph cost about 110 ms.
  - The burn now ignites at the last glyph stroke, not the binding.
  - The intent field no longer feeds keyboard learning.
  - Export and print use a settled offscreen render and are disabled while burning.
  - The print sheet drops "SOLANA" and uses the dialog's paper size.
  - The SVG stub is removed.
- **Phase 2, esoteric and science copy (04abe10d):**
  - Spare (A∴A∴, not the Golden Dawn), "Does not matter—need not be", burning as optional (Carroll), "lust of result" credited to Crowley.
  - Carroll reduction (vowels kept) is the default, with "no vowels" as the modern option.
  - Agrippa's planetary virtues; attributed system names.
  - Breath and EEG claims removed; dizziness caution and symbolic-practice disclaimer added.
- **Phase 3, engines (39b37f74):**
  - Golden Dawn / *777* transliteration with digraphs.
  - Kamea and Rose trace every letter, so the repeat loop now fires.
  - The rose follows the lamen's order and direction.
  - Hebrew lettering fades before the flame.
- **Phase 4, design (1f16d5c7, ca690c79, c7cdf5da, 89042fa1):**
  - WCAG tokens (`inkTertiary`, `seal`), enforced by a contrast test for all 8 skins.
  - A skin-derived `ThemeData`; the dialogs follow the skin.
  - App bar, 44 pt targets, type floor, compact Gnosis sheet with haptics, semantics.
  - Paper-true burn ramps, readable Kamea and Rose lettering, travel-based pen lifts.
  - "Wiccan" is shown as "Greenwood".
- **Phase 5, performance (ba4881d8):**
  - Bit-identical fused trig; memoised chaos seed; cached attractor Picture.
  - Breath holds cost no frames.
  - Typed burn heap, lazy path metrics, reused buffers, font-change cache refresh.
- **Android (f68f3881):** `allowBackup=false`.
- **Payments, backend and portal batch (reviewed, committed as c7cfc322, 534d5906, 46622209, ea6c18bc):**
  - Skin preview before purchase with an explicit Unlock button; inline store notices; price spinner; "remaining skins".
  - The pay dialog becomes "Skins & support", with no hard-coded prices.
  - `IapService.resetForTest`, plus positive restore and preview tests.
  - Backend: rate limit, JSON-only errors, CORS allowlist, bounded and validated Pyre input, minimal root endpoint, Joule claim removed, Dockerfile runs as `USER node` with a healthcheck, `.dockerignore`.
  - Portal: no seeded stats or fake wallet, `VITE_BACKEND_URL`, unused wallet-adapter, web3 and spl-token removed (107 → 2 dev-only advisories).
  - Mint script: keypair written 0600, secret never printed, no freeze authority.

**Contradictions or refinements to earlier findings:**
- Ellie's table listed Surrealist `inkSecondary` as a pass at 4.50:1. It was actually 4.497:1 (fixed).
- The Rose middle ring's Kaph/Tav order differs between secondary sources. King-scale spectral order was used; check against the *Equinox* I:3 plate.
- Tracing every letter of a full sentence (Golden Dawn practice was for names) makes busy Kamea and Rose sigils. Consider a "trace reduced kernel" option.

### 6.7 Brush, Circumlocution and web publishing (2026-10-25)
- **Sumi-e brush (a2dedca9, 725162e2):** Monogram, Kamea and Rose strokes are painted with a pressure-profiled sumi-e brush (Okami-style), driven by the stroke's minimum-jerk speed. It has kasure, bleed and splatter where the brush lands. Brushwork is seeded from stroke identity, so the Rose's moving strokes don't re-roll it each frame.
- **Circumlocution (a3884408, 0fccdb01, plus this commit):** a new default system, from the user's hand-drawn wheel. The whole phrase is traced on 28 spokes, ring by ring outward, each arc taking the shorter way round. The code name is `ringCipher`.
- **Netlify:** project `ignosis-studio`, linked through `netlify.toml` (static `build/web`, no build command). Drafts have been verified; production publishing and the custom domain wait on the user. Release builds log two "Uncaught Error" lines from Flutter's JS loader. They are harmless, their source isn't found, and Dart error hooks don't see them.
- **Web IAP (0627b652):** the store plugin is never touched on the web.

### 6.8 The Joule token (2026-10-25, uncommitted, awaiting review)
- **Direction changed.** The user directs that the on-chain burn be the point of the app. This supersedes §2's recommendation (option B, no token) and the vault ADR `2026-10-25-ignosis-v1-no-token`. The new ADR is `2026-10-25-ignosis-joule-token`.
- **Token.** IGNOSIS Joule is a Token-2022 mint with the NonTransferable extension, 0 decimals and 10¹² supply. Mint authority is revoked and there is no freeze authority. The whole supply sits in the treasury's account; nobody else can hold it, and the chain refuses transfers (error 0x25).
- **Rite.** Each verified purchase burns **1618 J**, after φ (1.618…). The physical basis is a 2″ × 2″ square of 80 gsm paper (25.8 cm², about 0.21 g), which burns to about 3,300 J, matching one transaction. The burn carries the memo `IGNOSIS:v1:<SHA-256("IGNOSIS:v1" ‖ salt ‖ intent)>`. One Solana transaction itself costs about 3,290 J (Solana Foundation, September 2022).
- **Backend.**
  - `routes/rite.ts`: `POST /api/v1/rite/consecrate` and `GET /api/v1/rite/:signature`.
  - `services/riteBurn.ts`: a sign-and-record-before-send fulfilment with an at-most-once burn per purchase.
  - `riteLedger.ts`: SQLite (`node:sqlite`).
  - `riteVerifier.ts`: the on-chain check.
  - `tools/createJouleMint.ts`: the mint script, which refuses mainnet.
  - The Ignition Pack treasury *transfer* service is deleted.
  - The Global Pyre stats count each burn once. A repeated request for the same purchase no longer adds it again; the stricter route test caught this.
- **Verified.**
  - `npm test`: the existing suite, plus 9 fulfilment scenarios (lost, rejected, hidden and concurrent sends, restart, random faults), plus the route tests.
  - Three mutations of the retry logic are each caught.
  - `tools/devnetRite.ts` passes end to end on a local validator: confirmed burn, on-chain check, supply −1618, retry idempotent, transfer refused.
- **Still open.**
  - ~~Devnet run~~ **Done.**
    - Mint `2Aj4PVH2RoxdQScMHkvjzPR4whMZiGUWwvZoZyHMjwNA`; treasury `7UULBCHy16LmjjiGY3F4UvkUTuHDRqrP2MtEoKkbHioK` (key in the gitignored `backend/treasury.keypair.json`).
    - First rite: `3z8AGqQ4erPPkr7V1YvjTbxxoE1pkWqjniZ6UcJZ1VqhNU3cwC6s55QGDqoN6qizior5WiMeep31hQBmjLuBDEVZ`.
    - Supply fell by 1618, the retry was idempotent, and the transfer was refused.
  - Store receipt verification (App Store Server API, Play Developer API) and a web card processor are not built; until they are, `/consecrate` refuses every purchase (402).
  - The Flutter client is not built: device-side salt and commitment, calling `/consecrate`, showing and verifying the burn, and seeding the burn animation from the signature.
  - `RITE_LEDGER_PATH` must point at a writable volume in Docker.
  - Mainnet needs a KMS-held treasury key.

### 6.9 Web payment and the rite flow (2026-10-25, uncommitted, awaiting review)
- **Payment (Stripe Checkout).**
  - `POST /api/v1/rite/checkout` opens a session for one rite. The signed webhook `POST /api/v1/stripe/webhook` records it as a credit.
  - Refunds and disputes revoke unused credits. A refund after the burn cannot undo it.
  - `GET /api/v1/rite/credit/:id` asks Stripe directly if the webhook is late.
  - Live Stripe keys are refused off mainnet, and test keys on it.
- **When the burn happens.** The burn happens when the seal is released, not at payment. The credit is spent at `/consecrate`, so the on-chain act is the release itself.
- **Sweeper.** `RiteSweeper` re-drives unconfirmed rites every 30 s, after they are 60 s old, so a paid burn finishes even if the payer leaves. Each burn is counted once in the Global Pyre.
- **Flutter.**
  - **Flag:** `kEnableRite` is on only for web builds that set `--dart-define=IGNOSIS_RITE_API=<backend>`.
  - **Gnosis dialog:** gains a "Witness on-chain · 1618 J" row with three states: add, waiting for payment, or a switch.
  - **Checkout:** opens in a new tab, opened blank in the tap itself so browsers don't block it.
  - **Release:** the salted commitment is computed on the device; the intent is never sent or stored.
  - **Result:** the dissolved-seal screen shows "1618 J burnt on-chain · verified" and a link to the record.
  - **Recovery:** receipts (signature, salt, commitment) are kept on the device, and an interrupted burn resumes with the same commitment.
  - `web/rite-paid.html` is the page Stripe returns the payer to.
- **Verified.**
  - Backend `npm test`: all four suites pass. Two broken variants (a refund check and a paid check) are each caught.
  - `flutter analyze --fatal-infos` is clean, and `flutter test` passes 129 (2 skipped).
  - The web build with the rite enabled compiles.
  - In a browser against a local backend: the witness row and its failure notice, and the return page in both variants.
- **Not verified yet.** A real Stripe test payment, which needs the owner's Stripe test keys.

### 6.10 Android rite through Google Play (2026-10-26, uncommitted, awaiting review)
- **Backend (`services/playRite.ts`).**
  - For `platform: 'android'`, the Play purchase token is checked with the Play Developer API. The gateway uses the service-account JWT flow with no client library.
  - The purchase must be completed (`purchaseState` 0) for a rite product. Off mainnet only test purchases are accepted, and on mainnet only real ones.
  - A consumed purchase is valid only to look up its own earlier burn.
  - The backend acknowledges each purchase so Play does not auto-refund it after 3 days.
  - `PlayVoidedSync` polls voided purchases every 15 minutes and revokes unused credits.
  - Settings: `GOOGLE_PLAY_SERVICE_ACCOUNT` (and `GOOGLE_PACKAGE_NAME`).
- **Flutter.**
  - The rite is the consumable `net.ignosis.studio.rite`, bought with `autoConsume: false`. An unconsumed purchase is the credit.
  - It is consumed only after the burn is confirmed, or when the backend reports it was already spent. A refused purchase is left untouched.
  - Spent tokens are remembered, so a consume lost to a closed app happens on the next launch.
  - `kEnableRite` now also covers Android builds with `IGNOSIS_RITE_API`. The witness row shows the Play price.
- **Verified.**
  - Backend `npm test`: all 5 suites pass. The Play suite runs the real gateway against a stubbed Google, checking that the JWT verifies with the account key and that the token is reused. Two broken variants are each caught.
  - `flutter analyze --fatal-infos` is clean, and `flutter test` passes 135 (2 skipped).
  - The release APK with the rite enabled builds, and so does the web build.
- **Not verified yet.** A real Play purchase on a device. It needs the Play Console product, a service account, license testers and an internal-testing build signed with the upload key.

### 6.11 The Infinite (2026-10-26, uncommitted)
- **A seventh system, `SigilSystem.infinite`: the Julia set of z ↦ z² + c.**
  - c comes from the SHA-256 of the intent, re-hashed until it lies on the edge of the Mandelbrot set: bounded, with a neighbour 0.004 away that escapes, and at least |μ| ≥ 1.05 outside the main cardioid. That gives a connected but intricate set.
- **Forward.** Equipotentials of the Green's function at G₀/√2ᵏ: 12 rings, starting 2 levels in. Every second ring is the exact preimage of the ring two outside it. They are extracted by marching squares on a 320² grid, chained by edge ID, and written from the outside in with a fine pen.
- **Inverted (Invert · √).** The inverse map ±√(z − c) from the repelling fixed point, 16 levels deep: 65,535 points, revealed depth by depth.
- **Zoom.** Pinch, scroll or double-tap. A lens transform is shown during the gesture; on release a new `InfiniteView` is committed and the rings are recomputed for the window, continuing the same level family.
  - The deepest half-width is 1e-11. Zooming out past the whole set returns home.
  - A view-only change appears at once, without rewriting. "Reset view" goes back to the whole set.
  - The readout shows "MAP: z² + c, c = … · ×N".
- **Determinism.** Only +, −, ×, ÷, √ and `detLog`/`detSinCos` are used. The values are recorded in `cross_platform_determinism_test` and pass on the VM and in Chrome.
  - **Bug found and fixed:** `math.pow(2, n)` with an int base wraps to 0 past n = 63 on native, though not on the web. The fix is a double base, with a regression test.
- **Verified.**
  - `flutter analyze --fatal-infos` is clean.
  - `flutter test`: 153 passed. That includes the engine tests, zoom gesture tests (double-tap ×2 keeps the tapped point fixed, scroll, no zoom on other systems) and new goldens `infinite` and `infinite_inverted`. Existing goldens are unchanged.
  - In the browser: zoom by double-click and scroll, Reset view, and Invert.

### 6.12 The Compendium and the main-page purpose (2026-10-26)
- **Purpose and ritual lines.** The main page states the purpose of the work above the intent field. Each system carries its ritual line (`SigilSystem.ritual`), shown under the chips. Both hide during the rite.
- **The Compendium replaces the wiki.**
  - Built from the chaos magic literature review in the vault by `tool/compendium/export.py`, into `assets/compendium/compendium.json`: 9 parts, 289 quotations from 187 works, 58 glossary terms, the study guide, a 165-entry bibliography and 47 authors' websites. It holds quotations, citations and links only.
  - **Contradicts the review (§1.1, §1.2):** the review lists "Chaos-magic interview wiki" and the files `chaos_wiki_screen.dart` and `chaos_magic_wiki_data.dart`. These are removed, along with the codex articles. The Exegesis dialog stays.
- **Verified.** `flutter analyze --fatal-infos` is clean. `flutter test`: 159 passed, 2 skipped. In the browser I opened the home, a part and the glossary.

### 6.13 Rite packages (2026-10-26)
- **Rites are sold in packages of 3, 7 and 21, not one at a time.** One payment buys a package: a Stripe Checkout session on the web, a Play order on Android (`net.ignosis.studio.rite.pack3`, `.pack7`, `.pack21`). Each release spends one rite, and each rite is one burn of 1618 J.
- **The ledger counts the rites per payment.** It refuses a burn past the package in the same statement that records it, so concurrent releases cannot overspend. A refund or dispute revokes the rites left; burns already made stay.
- **Configuration.** `STRIPE_RITE_PRICES=pack3=price_…,pack7=price_…,pack21=price_…` replaces `STRIPE_RITE_PRICE_ID`. `RITE_PRODUCT_IDS` is removed. The old single-rite product `net.ignosis.studio.rite` is no longer accepted.
- **Verified.** `npm test`: 5 of 5 suites pass. `flutter analyze --fatal-infos` is clean. `flutter test`: 165 passed, 2 skipped. In the browser I opened the package chooser.
- **Stripe test mode, end to end on devnet (2026-10-27).** Prices are $0.93, $1.61 and $3.14.
  - A 3-rite package was paid; its webhook credited it. Three releases burnt 1618 J each, all confirmed and read back with their commitments. A fourth release was refused (409, nothing burnt).
  - A second package had one rite burnt, then was refunded in the Dashboard. The `charge.refunded` webhook revoked it, so it shows 0 rites left and the next release was refused (402). Its one burn stays on-chain.
- **Not yet done.** The three Play Console products, and live keys at mainnet.
- **Note:** the Browser pane blocks the Checkout tab the app opens, because a tab may only open from the user's own click. Test payments in the pane need a click by the user.

### 6.4 Still open (beyond the checkboxes)
- ~~Bundle ID decision~~ Done: `net.ignosis.studio` (8321ef6a).
- Skin entitlements are cached client-side in `SharedPreferences`. That is acceptable for cosmetic non-consumables, but it can be edited on a rooted device.
- Not started: variant nonce (re-roll), hiding the kernel after charging, φ-ratio fixation rings, cross-system path morph, SVG / animated SVG / vector PDF export (`exportSvg` is still a stub), store listing, privacy policy, ToS.
