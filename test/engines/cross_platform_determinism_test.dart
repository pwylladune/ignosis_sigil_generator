import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/engines/cyber_chaos_engine.dart';
import 'package:ignosis_sigil_generator/src/models/intent_kernel.dart';
import 'package:ignosis_sigil_generator/src/motion/det_math.dart';
import 'package:ignosis_sigil_generator/src/motion/noise.dart';

/// Golden constants recorded on the Dart VM. The same file must pass on the
/// web too:  flutter test --platform chrome test/engines/cross_platform_determinism_test.dart
void main() {
  test('det_math matches dart:math to a few ulp', () {
    for (var i = -4000; i <= 4000; i++) {
      final x = i * 0.0137;
      expect(detSin(x), closeTo(math.sin(x), 4e-16 * math.max(1, x.abs())));
      expect(detCos(x), closeTo(math.cos(x), 4e-16 * math.max(1, x.abs())));
    }
    for (final x in <double>[1e-300, 1e-9, 0.1, 0.5, 1, 1.4142, 2, 3.7, 1e3, 1e300]) {
      expect(detLog(x), closeTo(math.log(x), 1e-15 * math.max(1, math.log(x).abs())));
    }
  });

  test('Cyber Chaos is bit-identical to the recorded VM output', () {
    const cases = [
      ('I COMMAND RADIANT CLARITY', 12, -1.5450980392156863, 1.3229877164873733, -1.0345311665522239, 0.9004348821240558,
          324.7446594238281, 282.1650390625, 207.78228759765625, 236.05511474609375),
      ('FOCUS', 1, -1.3154192416266117, -0.9152056153200581, 1.877256427862974, 1.373708705271992, 125.29122924804688,
          120.28499603271484, 231.7311248779297, 232.65789794921875),
      ('PROTECTION AND FORCE', 18, -1.101792935072862, -0.8173647669184405, 1.529777981231403, 1.8478370336461434,
          219.0486602783203, 215.78138732910156, 222.32421875, 321.08343505859375),
    ];
    for (final (intent, attempts, a, b, c, d, x0, y0, xn, yn) in cases) {
      final kernel = IntentKernel.fromText(intent);
      final (p, n) = CyberChaosEngine.seed(kernel);
      expect((n, p.a, p.b, p.c, p.d), (attempts, a, b, c, d), reason: intent);
      final g = CyberChaosEngine().build(kernel, const Size(400, 400), symmetryFolds: 3);
      // The last point is ~60,000 chaotic iterations in: any ulp drift shows here.
      expect([g.points[0], g.points[1], g.points[119998], g.points[119999]], [x0, y0, xn, yn], reason: intent);
    }
  });

  test('SeededRandom and noise match recorded values', () {
    final r = SeededRandom(42);
    expect([r.nextUint32(), r.nextUint32(), r.nextUint32()], [11355432, 2836018348, 476557059]);
    expect([valueNoise3(1.3, 2.7, 0.5, 7), valueNoise3(-12.25, 40.5, 3.75, 99)], [0.6208112005058893, 0.42850827764104316]);
  });
}
