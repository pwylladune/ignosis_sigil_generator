import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/engines/kamea_engine.dart';
import 'package:ignosis_sigil_generator/src/geometry/sigil_geometry.dart';
import 'package:ignosis_sigil_generator/src/models/hebrew_letters.dart';
import 'package:ignosis_sigil_generator/src/models/intent_kernel.dart';

void main() {
  group('planetary squares', () {
    for (final type in PlanetaryKameaType.values) {
      test('${type.name} is a normal magic square summing to M', () {
        final n = type.size;
        final sq = KameaEngine.square(type);
        final m = KameaEngine.magicConstant(n);
        expect(sq.length, n * n);
        expect(sq.toSet(), {for (var v = 1; v <= n * n; v++) v});
        for (var i = 0; i < n; i++) {
          expect([for (var j = 0; j < n; j++) sq[i * n + j]].reduce((a, b) => a + b), m, reason: 'row $i');
          expect([for (var j = 0; j < n; j++) sq[j * n + i]].reduce((a, b) => a + b), m, reason: 'col $i');
        }
        expect([for (var i = 0; i < n; i++) sq[i * n + i]].reduce((a, b) => a + b), m, reason: 'diagonal');
        expect([for (var i = 0; i < n; i++) sq[i * n + n - 1 - i]].reduce((a, b) => a + b), m, reason: 'anti-diagonal');
      });
    }

    test('magic constants match the tradition', () {
      expect([for (final t in PlanetaryKameaType.values) KameaEngine.magicConstant(t.size)], [15, 34, 65, 111, 175, 260, 369]);
    });
  });

  group('Aiq Bekar letter mapping', () {
    test('every Latin letter lands inside every square', () {
      for (final t in PlanetaryKameaType.values) {
        for (var c = 65; c <= 90; c++) {
          final v = KameaEngine.letterNumber(String.fromCharCode(c), t.size);
          expect(v, inInclusiveRange(1, t.size * t.size));
        }
      }
    });

    test('reduces tens and hundreds into their chamber', () {
      expect(aiqBekarReduce(200, 9), 2); // Resh on Saturn
      expect(aiqBekarReduce(400, 16), 4); // Tav on Jupiter
      expect(aiqBekarReduce(100, 81), 10); // Qoph on Luna
      expect(aiqBekarReduce(90, 81), 9); // Tzaddi on Luna
      expect(aiqBekarReduce(40, 81), 40); // Mem fits on Luna
      expect(KameaEngine.letterNumber('R', 3), 2);
      expect(KameaEngine.letterNumber('M', 6), 4); // 40 > 36 → 4
    });
  });

  group('KameaEngine.build', () {
    const size = Size(400, 300); // non-square canvas
    final kernel = IntentKernel.fromText('MY WILL IS LAW');

    test('one node per letter, every node in a square cell', () {
      for (final t in PlanetaryKameaType.values) {
        final s = KameaEngine().build(kernel, t, size);
        expect(s.numbers.length, kernel.length);
        expect(s.cells.every((c) => c >= 0), isTrue);
        expect(s.layout.square.width, closeTo(s.layout.square.height, 1e-9));
        expect(s.layout.square.center, const Offset(200, 150));
        for (final p in s.geometry.nodes) {
          expect(s.layout.square.inflate(0.01).contains(p), isTrue);
        }
      }
    });

    test('grammar: start circle, traversal, terminal crossbar', () {
      final s = KameaEngine().build(kernel, PlanetaryKameaType.sol, size);
      expect(s.geometry.strokes.map((e) => e.role).toList(), [StrokeRole.startMark, StrokeRole.ink, StrokeRole.terminal]);
      expect(s.visitFractions.first, 0);
      expect(s.visitFractions.last, closeTo(1, 1e-9));
    });

    test('is deterministic', () {
      final a = KameaEngine().build(kernel, PlanetaryKameaType.venus, size);
      final b = KameaEngine().build(IntentKernel.fromText('MY WILL IS LAW'), PlanetaryKameaType.venus, size);
      expect(a.cells, b.cells);
      expect(a.geometry.nodes, b.geometry.nodes);
    });

    test('empty intent yields empty geometry', () {
      expect(KameaEngine().build(IntentKernel.fromText(''), PlanetaryKameaType.mars, size).geometry.isEmpty, isTrue);
    });
  });
}
