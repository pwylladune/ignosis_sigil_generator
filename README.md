# IGNOSIS — Chaos Magic Sigil Studio

IGNOSIS turns a statement of intent into a sigil and lets you charge and release it. It is a Flutter app
for iOS, Android and the web, drawn in a minimal Pen & Ink style with a vermilion accent.

**Same intent, same sigil.** Every engine is a deterministic function of the reduced intent and its
options. **Nothing moves unless the math moves it.** Every animation is the time evolution of the
function that made the symbol.

## The five systems

| System | Mathematics | Motion |
|---|---|---|
| **Monogram (after Spare)** | Repeated letters struck out (Carroll; optionally vowels too, a modern convention) → radicals on one shared armature, coincident strokes merged; the domain is replicated by Cₙ or Dₙ (the symmetry is IGNOSIS's own) | The domain is written, then each copy turns (and in Dₙ flips) into place |
| **Planetary Kamea** | Every letter → Hebrew (Golden Dawn / *777* transliteration, digraphs first) → gematria → Aiq Bekar reduction into Agrippa's square (Saturn 3×3 … Luna 9×9); repeats loop | The pen traverses cell to cell at constant speed; numbers glow; every row, column and diagonal lights to the magic constant M |
| **Golden Dawn Rose** | The 22-petal rose of the Rose Cross lamen (3 mothers, 7 doubles, 12 simples) in the lamen's order and direction | Rings counter-rotate in ratio 3 : 7 : 12 and lock as the last stroke lands |
| **Cymatic (Chladni)** | Free square plate mode `cos(nπx)cos(mπy) ± cos(mπx)cos(nπy)`; nodal set by marching squares | 3,600 grains descend `f²` onto the nodal lines; a new intent morphs the mode and the sand flows |
| **Cyber Chaos** | SHA-256 → Clifford attractor parameters, rejected unless chaotic (Lyapunov > 0) and well filled | The orbit accretes like ink soaking into paper |

**Ritual Combustion** burns the seal in reverse ductus from the last glyph stroke. A baked
ignition-distance field drives a level-set shader (char-dominant on light paper, blackbody on dark),
the ink acts as the fuse, embers ride curl noise, and construction lettering fades before the flame. Before the release, a Gnosis
breath guide (resonance 5.5/min, box, or 4-7-8) sets the rhythm for both the dialog and the canvas.
Reduce-motion settings are honoured everywhere.

## Getting started

Requirements: Flutter stable (3.44+, Dart 3.12). Building for iOS needs Xcode 27 and CocoaPods;
Android needs the Android SDK 36 and JDK 17.

```bash
flutter pub get
flutter run -d chrome        # or an iOS simulator / Android emulator
flutter analyze
flutter test                 # unit, property and widget tests
flutter test --tags golden   # pixel goldens (generated on macOS)
```

To render preview frames of each engine through its motion, run:

```bash
VISUAL_OUT=build/visual flutter test --tags visual --run-skipped test/visual
```

Optional variables: `VISUAL_SYSTEMS=spare,kamea`, `VISUAL_TIMES=0.5,2,6`, `VISUAL_BURN=6`,
`VISUAL_FOLDS`, `VISUAL_GROUP`, `VISUAL_PLANET`, `VISUAL_SKIN`, `VISUAL_INTENT`.

## Architecture

```
lib/
  main.dart                     App entry; store init runs in the background
  src/config/feature_flags.dart kEnableChain (false for v1.0: no token, no wallet UI)
  src/models/                   IntentKernel (Spare reduction), Hebrew letters + Aiq Bekar, state
  src/engines/                  Pure math: one engine per system → geometry (ordered strokes)
  src/geometry/                 SigilGeometry, GeometryCache, BurnField (ignition distance)
  src/motion/                   MotionClock (single ticker), minimum-jerk easing, ductus, breath, noise
  src/ui/canvas/                SigilCanvas + one scene per engine + Combustion
  src/ui/screens|widgets|theme  Studio, Gnosis dialog, wiki, 8 skins
assets/shaders/combustion.frag  Level-set burn front
```

Engines know nothing about time. Scenes turn geometry into motion as pure functions of the clock.
The canvas runs its ticker only while something is moving, so an idle studio uses no frames.

## Monetisation (v1.0)

The core studio is free: all five systems, the burn, PNG share and the printable PDF burn sheet.
The seven premium skins are one-time in-app purchases, sold individually or as a bundle, and
Restore Purchases is available. v1.0 has **no cryptocurrency features**. The `backend/`,
`contracts/`, `portal/` and `scripts/` folders are prototypes of a deferred on-chain design. Read
[`TASK.md`](TASK.md) before touching them. They are not safe to deploy, and
[`docs/deployment_guide.md`](docs/deployment_guide.md) marks the sections that describe simulated
behaviour.

## Status

[`TASK.md`](TASK.md) is the source of truth for state, findings and priorities.
