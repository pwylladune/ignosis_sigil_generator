"""The IGNOSIS symbol from "Michael Roland": every constant below is read off
IGNOSIS's own engines for that name (see the printed derivation)."""
import cmath, math, sys
TAU = 2 * math.pi
s = TAU / 28                                   # Circumlocution: one spoke of 28
spoke = lambda i: -math.pi / 2 + (i - 6.5) * s
sweeps = [-4, -6, 5, -7, 4, 7, 6, -3, -3, -11, 13, -10]   # the name's walk (spokes)
phi = (spoke(12), sum(sweeps) * s, spoke(3))   # M (first), net turn, D (last)
A = (12, 7, 3)                                 # Rose: simples, doubles, mothers
n, m = 1, 3                                    # Chladni mode of the name
N0 = 3                                         # Rose mothers; √ doubles it to Sol's 6
K = (1, 1 - N0 * n, 1 + N0 * m)                # Monogram: harmonics ≡ 1 (mod 3)
a, b, c, d = -1.1918822003509575, -1.1831540398260472, 1.876401922636759, -1.0925154497596705
cJ = complex(-0.5374069213867188, -0.59381103515625)      # The Infinite
eps = 1 / 16

def Z(t):
    return sum(Ai * cmath.exp(1j * (k * t + p)) for Ai, k, p in zip(A, K, phi)) / sum(A)

def W(z):
    r = abs(z)
    return z * (1 + eps * (math.sin(math.pi * a * r) + c * math.cos(math.pi * b * r) + d))

def symbol(T=12000):
    rot = cmath.exp(1j * cmath.phase(cJ) / 2)
    pts, prev = [], None
    for i in range(T):
        w = cmath.sqrt(W(Z(2 * TAU * i / T)))     # t over [0, 4π]
        if prev is not None and abs(w - prev) > abs(-w - prev):
            w = -w                                  # follow the root continuously
        pts.append(w); prev = w
    return [rot * w for w in pts]

def svg(size=1024, stroke=None, paper='#F7F5F0', ink='#141416', seal='#C0392B', bg=True):
    pts = symbol()
    R = max(abs(p) for p in pts)
    sc = size * 0.42 / R
    cx = cy = size / 2
    d_ = 'M ' + ' L '.join(f'{cx + sc * p.real:.2f} {cy - sc * p.imag:.2f}' for p in pts) + ' Z'
    sw = stroke or size / 64
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">']
    if bg:
        out.append(f'<rect width="{size}" height="{size}" fill="{paper}"/>')
    out.append(f'<path d="{d_}" fill="none" stroke="{ink}" stroke-width="{sw:.2f}" stroke-linejoin="round" stroke-linecap="round"/>')
    out.append(f'<circle cx="{cx}" cy="{cy}" r="{size / 48:.2f}" fill="{seal}"/>')
    out.append('</svg>')
    return '\n'.join(out)

if __name__ == '__main__':
    print('phi =', phi, 'K =', K, 'arg(c)/2 =', cmath.phase(cJ) / 2)
    open('ignosis_symbol.svg', 'w').write(svg())
    open('ignosis_symbol_dark.svg', 'w').write(svg(paper='#111113', ink='#ECECEE', seal='#E5484D'))
    for px in (48, 96, 192):
        open(f'ignosis_symbol_{px}.svg', 'w').write(svg(size=px, stroke=max(2.0, px / 40)))
