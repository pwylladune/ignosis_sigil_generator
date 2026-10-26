import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/engines/infinite_engine.dart';
import 'package:ignosis_sigil_generator/src/models/intent_kernel.dart';

void main() {
  const size = Size(512, 512);
  final kernel = IntentKernel.fromText('I COMMAND RADIANT CLARITY');

  test('c lies on the edge of the Mandelbrot set: connected, and intricate', () {
    for (final text in ['I COMMAND RADIANT CLARITY', 'IT IS MY WILL TO SEE', 'A', 'THE INFINITE']) {
      final c = JuliaParams.fromKernel(IntentKernel.fromText(text));
      expect(JuliaParams.bounded(c.cx, c.cy), isTrue, reason: '$text: $c');
      expect(JuliaParams.onEdge(c.cx, c.cy), isTrue, reason: '$text: $c');
      expect(JuliaParams.inMainCardioid(c.cx, c.cy), isFalse, reason: 'a bulb or filament, not the smooth cardioid');
      expect(c, isNot(JuliaParams.rabbit), reason: 'found by the hash chain, not the fallback');
    }
  });

  test('same intent, same Infinite; another intent, another', () {
    final a = InfiniteEngine().build(kernel, size);
    final b = InfiniteEngine().build(IntentKernel.fromText('I COMMAND RADIANT CLARITY'), size);
    final other = InfiniteEngine().build(IntentKernel.fromText('IT IS MY WILL TO SEE'), size);
    expect(a.params, b.params);
    expect(a.geometry.strokes.length, b.geometry.strokes.length);
    expect(a.geometry.totalLength, b.geometry.totalLength);
    expect(other.params, isNot(a.params));
  });

  test('forward: the levels are written outermost first, each ring inside the last', () {
    final s = InfiniteEngine().build(kernel, size);
    expect(s.geometry.strokes, isNotEmpty);
    expect(s.strokeLevels.toSet(), {for (var k = 0; k < InfiniteEngine.levels; k++) k});
    // Levels never go back outward.
    for (var i = 1; i < s.strokeLevels.length; i++) {
      expect(s.strokeLevels[i], greaterThanOrEqualTo(s.strokeLevels[i - 1]));
    }
    // Each ring lies inside the one before: the levels nest toward the set.
    Rect levelBounds(int k) => [
          for (var i = 0; i < s.strokeLevels.length; i++)
            if (s.strokeLevels[i] == k) s.geometry.strokes[i].path.getBounds()
        ].reduce((a, b) => a.expandToInclude(b));
    for (var k = 1; k < InfiniteEngine.levels; k++) {
      final outer = levelBounds(k - 1).inflate(0.5), inner = levelBounds(k);
      expect(outer.contains(inner.topLeft) && outer.contains(inner.bottomRight), isTrue, reason: 'level $k');
    }
    // Every second level is the preimage of the one two outside it.
    expect(InfiniteEngine.level(2) * 2, closeTo(InfiniteEngine.level(0), 1e-15));
    // Everything stays on the plate.
    final bounds = s.geometry.strokes.map((x) => x.path.getBounds()).reduce((a, b) => a.expandToInclude(b));
    expect((bounds.center - s.center).distance, lessThan(s.radius));
    expect(bounds.width, lessThanOrEqualTo(2 * s.radius + 1));
  });

  test('Green’s function doubles under the map: G(z² + c) = 2·G(z)', () {
    final c = JuliaParams.fromKernel(kernel);
    for (final (re, im) in [(1.2, 0.3), (-0.9, 0.8), (0.1, -1.4)]) {
      final g = InfiniteEngine.green(re, im, c, 80);
      final g2 = InfiniteEngine.green(re * re - im * im + c.cx, 2 * re * im + c.cy, c, 80);
      expect(g2, closeTo(2 * g, 1e-9 + 1e-6 * g));
    }
  });

  test('slow escapes stay finite: 2ⁿ is a double, not a wrapping int', () {
    final c = JuliaParams.fromKernel(kernel);
    // This point escapes only after 70 steps.
    final g = InfiniteEngine.green(
        -0.04116683361691557 + 0.2 * (2 * 9 / 12 - 1), 1.1844358075182966 + 0.2 * (2 * 1 / 12 - 1), c, 200);
    expect(g.isFinite, isTrue);
    expect(g, greaterThan(0));
    expect(g, lessThan(1e-18));
  });

  test('the set is symmetric under z ↦ −z (forward rings and inverse points)', () {
    final s = InfiniteEngine().build(kernel, size);
    final b = s.geometry.strokes.map((x) => x.path.getBounds()).reduce((a, b) => a.expandToInclude(b));
    expect((b.center - s.center).distance, lessThan(4));
    final inv = InfiniteEngine().build(kernel, size, inverted: true);
    var sx = 0.0, sy = 0.0;
    for (var k = 0; k < inv.pointCount; k++) {
      sx += inv.points[2 * k] - inv.center.dx;
      sy += inv.points[2 * k + 1] - inv.center.dy;
    }
    expect(Offset(sx, sy).distance / inv.pointCount, lessThan(1));
  });

  test('inverted: the square roots land on the set, never escaping', () {
    final inv = InfiniteEngine().build(kernel, size, inverted: true);
    expect(inv.pointCount, greaterThan(30000));
    final c = inv.params;
    // A point of the Julia set never escapes under the forward map.
    for (var k = 0; k < inv.pointCount; k += 997) {
      final (re, im) = InfiniteEngine.toComplex(
          Offset(inv.points[2 * k], inv.points[2 * k + 1]), inv.view, inv.center, inv.radius);
      expect(InfiniteEngine.green(re, im, c, 60), lessThan(1e-3));
    }
    expect(inv.geometry.strokes, hasLength(1), reason: 'marks for the burn');
  });

  test('zooming continues the same family of rings deeper in', () {
    final home = InfiniteEngine().build(kernel, size);
    // Zoom ×8 onto a point on the outermost ring.
    final p = home.geometry.strokes.first.path.computeMetrics().first.getTangentForOffset(10)!.position;
    final (re, im) = InfiniteEngine.toComplex(p, home.view, home.center, home.radius);
    final view = InfiniteView(re, im, home.view.halfWidth / 8);
    final zoomed = InfiniteEngine().build(kernel, size, view: view);
    expect(zoomed.geometry.strokes, isNotEmpty);
    expect(view.magnificationFrom(home.view), closeTo(8, 1e-9));
    final (cr, ci) = InfiniteEngine.toComplex(zoomed.center, view, zoomed.center, zoomed.radius);
    expect((cr, ci), (re, im));
  });

  test('an empty intent draws nothing', () {
    expect(InfiniteEngine().build(IntentKernel.fromText(''), size).geometry.isEmpty, isTrue);
    expect(InfiniteEngine().build(IntentKernel.fromText(''), size, inverted: true).pointCount, 0);
  });
}
