import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/engines/cyber_chaos_engine.dart';
import 'package:ignosis_sigil_generator/src/models/intent_kernel.dart';

void main() {
  test('rejects non-chaotic parameters', () {
    // Small parameters contract to a fixed point.
    const calm = CliffordParams(0.1, 0.1, 0.1, 0.1);
    expect(calm.lyapunov(), lessThan(0));
    expect(calm.isChaotic, isFalse);
    expect(CliffordParams.fallback.isChaotic, isTrue);
  });

  test('every intent yields a chaotic, well-filled seed', () {
    for (final s in ['FOCUS', 'WEALTH', 'PROTECTION AND FORCE', 'I COMMAND RADIANT CLARITY', 'IGNOSIS CONSECRATION', 'Z', 'XQ']) {
      final (p, attempts) = CyberChaosEngine.seed(IntentKernel.fromText(s));
      expect(p.lyapunov(), greaterThan(CliffordParams.minLyapunov), reason: s);
      expect(p.fill(), greaterThan(CliffordParams.minFill), reason: s);
      expect(attempts, lessThanOrEqualTo(64), reason: '$s fell back to the default seed');
    }
  });

  test('is deterministic', () {
    const size = Size(400, 400);
    final a = CyberChaosEngine().build(IntentKernel.fromText('IGNOSIS CONSECRATION'), size, symmetryFolds: 4);
    final b = CyberChaosEngine().build(IntentKernel.fromText('IGNOSIS CONSECRATION'), size, symmetryFolds: 4);
    expect(a.points, b.points);
    expect(a.params.toString(), b.params.toString());
  });

  test('points fit inside the plate', () {
    const size = Size(400, 400);
    for (final folds in [1, 3, 6]) {
      final s = CyberChaosEngine().build(IntentKernel.fromText('CHAOS'), size, symmetryFolds: folds);
      for (var i = 0; i < s.count; i += 97) {
        final dx = s.points[2 * i] - 200, dy = s.points[2 * i + 1] - 200;
        expect(math.sqrt(dx * dx + dy * dy), lessThanOrEqualTo(160.01));
      }
    }
  });
}
