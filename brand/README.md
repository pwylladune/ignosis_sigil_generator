# The IGNOSIS symbol

Drawn from the name **Michael Roland** by IGNOSIS's own mathematics, one part from each of the seven systems.
`ignosis_symbol.py` regenerates the SVGs exactly; nothing in it is drawn by hand.

## The equation

$$
w(t) \;=\; e^{\,i\psi}\,\sqrt{\,Z(t)\Big[\,1+\tfrac{1}{16}\big(\sin(\pi a\,|Z(t)|)\;+\;c\,\cos(\pi b\,|Z(t)|)\;+\;d\big)\Big]}\,,\qquad t\in[0,\,4\pi]
$$

$$
Z(t) \;=\; \frac{12\,e^{\,i(t-\frac{3\pi}{28})}\;+\;7\,e^{\,i(-2t-\frac{9\pi}{14})}\;+\;3\,e^{\,i(10t-\frac{3\pi}{4})}}{22}
$$

The square root is followed continuously, so the curve closes after two turns of t. The vermilion seal sits at w = 0.

| Constant | Value | Source |
|---|---|---|
| a, b, c, d | −1.191882, −1.183154, 1.876402, −1.092515 | **Cyber Chaos**: the Clifford attractor parameters that IGNOSIS derives from SHA-256 of the name (12th hash) |
| ψ | ½·arg(−0.537407 − 0.593811i) = −1.153187 | **The Infinite**: half the angle of the name's Julia constant c. The √ is its inverse map |

## How each system contributes
- **Circumlocution: the phases.** On the 28-spoke wheel the name starts at M (−3π/28) and ends at D (−3π/4). Its 12 arcs sweep −4, −6, +5, −7, +4, +7, +6, −3, −3, −11, +13, −10 spokes, a net turn of −9 spokes (−9π/14).
- **Golden Dawn Rose: the amplitudes and the threefold seed.** 12 : 7 : 3 are the rose's simples, doubles and mothers, and the rosette before the root has the three mothers' symmetry.
- **Cymatic Resonance: which harmonics.** The name's Chladni mode is (n, m) = (1, 3), so the frequencies are 1, 1 − 3n = −2 and 1 + 3m = 10.
- **Monogram (after Spare): the group.** Frequencies ≡ 1 (mod 3) make the rosette a C₃ group assembly of one fundamental arc.
- **Planetary Kamea: the six.** The name in Hebrew (Golden Dawn / *777*) has gematria 449. The smallest of Agrippa's squares whose total holds it is Sol (6 × 6, total 666), and the √ doubles C₃ to Sol's C₆.
- **Cyber Chaos: the warp.** One Clifford-shaped step, with a, b, c, d, bends the rosette's radius. It is radial, so the symmetry is kept.
- **The Infinite: the root and the turn.** w = √(·) is the inverse of z ↦ z² (the "Invert · √" of The Infinite), and e^{iψ} turns the seal to the direction of the name's Julia constant.

---

# "Rise In Power"

The two-fold **Cyber Chaos** attractor of **Michael Roland**, inside the **Circumlocution** walk of **Rise In Power**, painted with the studio's sumi-e brush. Files: `rise_in_power_icon.png` (light) and `rise_in_power_icon_dark.png` (dark), both 1024 px. Regenerate with:

```bash
flutter test brand/rise_in_power_icon_test.dart
```

**The centre: the Cyber Chaos attractor.**
- The parameters come from the name's SHA-256, accepted on the 12th hash as chaotic:

$$x_{n+1} = \sin(a\,y_n) + c\cos(a\,x_n),\qquad y_{n+1} = \sin(b\,x_n) + d\cos(b\,y_n)$$

  with a = −1.191882, b = −1.183154, c = 1.876402, d = −1.092515.
- 60,000 points are folded by C₂ (every other point is turned by π) and fitted to a radius of 86 on the 512-unit plate. They are drawn as ink soaking into paper.

**The halo: the Circumlocution walk.**
- RISEINPOWER is walked on the 28-spoke wheel (spoke i at −π/2 + (i − 6.5)·2π/28): 10 arcs, ring by ring from radius 98 to 242, each the short way round.
- The arc sweeps, in spokes, are R→I −9, I→S +10, S→E +14 (a half-turn goes clockwise), E→I +4, I→N +5, N→P +2, P→O −1, O→W +8, W→E +10, E→R +13.

**The brush.** The arcs are painted with the studio's Ōkami-style brush, seeded with 1618: pressure that swells and tapers, dry-brush streaks, and splatter only where the brush lands.

**The seal.** The vermilion bind point sits at the centre.
