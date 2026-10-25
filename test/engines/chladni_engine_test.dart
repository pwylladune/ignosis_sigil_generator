import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/engines/chladni_engine.dart';
import 'package:ignosis_sigil_generator/src/models/intent_kernel.dart';
import 'package:ignosis_sigil_generator/src/ui/canvas/chladni_scene.dart';

void main() {
  test('mode pairs are distinct and structured', () {
    for (final (n, m) in ChladniMode.pairs) {
      expect(n, lessThan(m));
      expect(n + m, greaterThanOrEqualTo(4));
    }
  });

  test('mode is deterministic and depends on the intent', () {
    final a = ChladniMode.fromKernel(IntentKernel.fromText('CHAOS AND HARMONY'));
    final b = ChladniMode.fromKernel(IntentKernel.fromText('chaos and harmony'));
    expect(a, b);
    final modes = {
      for (final s in ['FOCUS', 'WEALTH', 'PROTECTION', 'CLARITY', 'COURAGE', 'HEALING', 'LOVE', 'SILENCE'])
        ChladniMode.fromKernel(IntentKernel.fromText(s)),
    };
    expect(modes.length, greaterThan(3));
  });

  test('gradient matches finite differences', () {
    const mode = ChladniMode(2, 5, -1);
    for (final (x, y) in [(0.1, 0.3), (-0.7, 0.2), (0.45, -0.9)]) {
      const e = 1e-6;
      final (gx, gy) = mode.gradient(x, y);
      expect(gx, closeTo((mode.value(x + e, y) - mode.value(x - e, y)) / (2 * e), 1e-4));
      expect(gy, closeTo((mode.value(x, y + e) - mode.value(x, y - e)) / (2 * e), 1e-4));
    }
  });

  test('antisymmetric modes vanish on the diagonal', () {
    const mode = ChladniMode(1, 4, -1);
    for (var t = -1.0; t <= 1.0; t += 0.1) {
      expect(mode.value(t, t), closeTo(0, 1e-12));
    }
  });

  test('marching squares lands on the nodal set', () {
    const mode = ChladniMode(3, 5, 1);
    final segments = marchingSquares(mode.value);
    expect(segments, isNotEmpty);
    for (final (a, b) in segments) {
      // Linear interpolation error is O(h²·|∇²f|); h = 1/60.
      expect(mode.value(a.dx, a.dy).abs(), lessThan(0.08));
      expect(mode.value(b.dx, b.dy).abs(), lessThan(0.08));
    }
  });

  test('sand migrates onto the nodal lines', () {
    final sigil = ChladniEngine().build(IntentKernel.fromText('CHAOS AND HARMONY'), const Size(500, 500));
    final scene = ChladniScene(sigil, startTime: 0);
    final initial = scene.residualAt(0.0);
    final settled = scene.residualAt(5.0);
    expect(initial, greaterThan(0.3));
    expect(settled, lessThan(0.06));
  });

  test('sand flows from one mode into the next', () {
    const size = Size(500, 500);
    final a = ChladniEngine().build(IntentKernel.fromText('FOCUS'), size);
    final b = ChladniEngine().build(IntentKernel.fromText('SILENCE'), size);
    expect(a.mode, isNot(b.mode));
    final first = ChladniScene(a, startTime: 0)..residualAt(5);
    final second = ChladniScene(b, startTime: 5, previous: first);
    expect(second.residualAt(0), greaterThan(0.1));
    expect(second.residualAt(6), lessThan(0.06));
  });
}
