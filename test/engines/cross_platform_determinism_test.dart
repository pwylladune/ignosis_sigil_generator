import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/engines/cyber_chaos_engine.dart';
import 'package:ignosis_sigil_generator/src/engines/infinite_engine.dart';
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

  test('detSinCos returns exactly detSin and detCos', () {
    for (var i = -3000; i <= 3000; i++) {
      final x = i * 0.0731;
      final (s, c) = detSinCos(x);
      expect(s, detSin(x));
      expect(c, detCos(x));
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

  test('The Infinite is bit-identical to the recorded VM output', () {
    const cases = [
      ('I COMMAND RADIANT CLARITY', -0.03974151611328125, -0.7957489013671875, 1.8318421541154386, 0.0450502544106376, 65535,
          320.4681701660156, 149.2913360595703, 192.51512145996094, 109.43579864501953),
      ('FOCUS', -1.26910400390625, -0.04042968750000009, 2.0517774085700515, 0.11866740031298703, 65535,
          348.6236267089844, 198.59323120117188, 136.93992614746094, 200.97671508789062),
      ('PROTECTION AND FORCE', -1.2464065551757812, -0.030918884277343794, 2.0439234821498395, 0.11643008814808115, 65535,
          348.3951110839844, 198.91183471679688, 137.43942260742188, 200.58934020996094),
    ];
    for (final (intent, cx, cy, home, g, count, x0, y0, xn, yn) in cases) {
      final kernel = IntentKernel.fromText(intent);
      final c = JuliaParams.fromKernel(kernel);
      expect((c.cx, c.cy, c.homeHalfWidth), (cx, cy, home), reason: intent);
      expect(InfiniteEngine.green(0.9, 0.4, c, 40), g, reason: intent);
      // 2¹⁶ square roots deep: any ulp drift in the inverse map shows here.
      final inv = InfiniteEngine().build(kernel, const Size(400, 400), inverted: true);
      final n = inv.points.length;
      expect((inv.pointCount, inv.points[0], inv.points[1], inv.points[n - 2], inv.points[n - 1]),
          (count, x0, y0, xn, yn), reason: intent);
    }
  });

  test('SeededRandom and noise match recorded values', () {
    final r = SeededRandom(42);
    expect([r.nextUint32(), r.nextUint32(), r.nextUint32()], [11355432, 2836018348, 476557059]);
    expect([valueNoise3(1.3, 2.7, 0.5, 7), valueNoise3(-12.25, 40.5, 3.75, 99)], [0.6208112005058893, 0.42850827764104316]);
  });
}
