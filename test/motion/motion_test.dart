import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/geometry/geometry_cache.dart';
import 'package:ignosis_sigil_generator/src/geometry/sigil_geometry.dart';
import 'package:ignosis_sigil_generator/src/motion/breath.dart';
import 'package:ignosis_sigil_generator/src/motion/ductus.dart';
import 'package:ignosis_sigil_generator/src/motion/easing.dart';
import 'package:ignosis_sigil_generator/src/motion/noise.dart';

Path _line(double len) => Path()
  ..moveTo(0, 0)
  ..lineTo(len, 0);

void main() {
  group('minimumJerk', () {
    test('rests at both ends', () {
      expect(minimumJerk(0), 0);
      expect(minimumJerk(1), 1);
      expect(minimumJerkVelocity(0), 0);
      expect(minimumJerkVelocity(1), 0);
      expect(minimumJerk(-1), 0);
      expect(minimumJerk(2), 1);
    });

    test('is symmetric and peaks in the middle', () {
      for (var t = 0.0; t <= 1.0; t += 0.05) {
        expect(minimumJerk(t) + minimumJerk(1 - t), closeTo(1, 1e-12));
      }
      expect(minimumJerk(0.5), closeTo(0.5, 1e-12));
      expect(minimumJerkVelocity(0.5), closeTo(1.875, 1e-12));
    });

    test('is monotonic and inverts', () {
      var prev = -1.0;
      for (var t = 0.0; t <= 1.0; t += 0.01) {
        final s = minimumJerk(t);
        expect(s, greaterThanOrEqualTo(prev));
        expect(inverseMinimumJerk(s), closeTo(t, 1e-6));
        prev = s;
      }
    });
  });

  group('cruise (constant-speed) profile', () {
    test('ends at rest positions, cruises at constant speed in the middle', () {
      expect(cruise(0), 0);
      expect(cruise(1), 1);
      const a = 0.12;
      final v = (cruise(0.6) - cruise(0.4)) / 0.2;
      expect(v, closeTo(1 / (1 - a), 1e-9));
      expect(cruise(0.5), closeTo(0.5, 1e-12));
      var prev = -1.0;
      for (var t = 0.0; t <= 1.0; t += 0.01) {
        expect(cruise(t), greaterThanOrEqualTo(prev));
        expect(inverseProfile(cruise, cruise(t)), closeTo(t, 1e-6));
        prev = cruise(t);
      }
    });

    test('DuctusTimeline applies a per-stroke profile', () {
      final g = SigilGeometry(strokes: [SigilStroke(_line(100))]);
      final d = DuctusTimeline(g, penSpeed: 100, profileFor: (_) => cruise);
      expect(d.fractionsAt(0.5).single, closeTo(0.5, 1e-9));
      expect(d.fractionsAt(0.3).single, closeTo(cruise(0.3), 1e-9));
      expect(d.timeAtFraction(0, cruise(0.3)), closeTo(0.3, 1e-6));
    });
  });

  group('BreathPattern', () {
    test('resonance breathing is 5.5 breaths per minute', () {
      expect(60 / BreathPattern.resonance.period, closeTo(5.5, 1e-9));
    });

    test('volume is continuous and bounded', () {
      for (final p in BreathPattern.values) {
        var prev = p.value(0);
        for (var t = 0.0; t < 3 * p.period; t += 0.01) {
          final v = p.value(t);
          expect(v, inInclusiveRange(0, 1));
          expect((v - prev).abs(), lessThan(0.02), reason: '${p.name} jumps at t=$t');
          prev = v;
        }
      }
    });

    test('counts cycles and phases', () {
      const p = BreathPattern.box;
      expect(p.sample(1).phase, BreathPhase.inhale);
      expect(p.sample(5).phase, BreathPhase.holdIn);
      expect(p.sample(9).phase, BreathPhase.exhale);
      expect(p.sample(13).phase, BreathPhase.holdOut);
      expect(p.sample(16.5).cycle, 1);
    });
  });

  group('DuctusTimeline', () {
    test('duration is proportional to ink length (constant pen speed)', () {
      final short = DuctusTimeline(SigilGeometry(strokes: [SigilStroke(_line(340))]), penSpeed: 340);
      final long = DuctusTimeline(SigilGeometry(strokes: [SigilStroke(_line(680))]), penSpeed: 340);
      expect(short.duration, closeTo(1, 1e-6));
      expect(long.duration, closeTo(2, 1e-6));
    });

    test('strokes are written in order, one at a time', () {
      final g = SigilGeometry(strokes: [SigilStroke(_line(100)), SigilStroke(_line(100))]);
      final d = DuctusTimeline(g, penSpeed: 100, liftPause: 0.1);
      expect(d.fractionsAt(0), [0, 0]);
      expect(d.fractionsAt(0.5)[0], closeTo(0.5, 1e-9));
      expect(d.fractionsAt(0.5)[1], 0);
      expect(d.fractionsAt(1.05), [1, 0]);
      expect(d.fractionsAt(d.duration), [1, 1]);
      expect(d.timeAtFraction(1, 0.5), closeTo(1.6, 1e-6));
    });
  });

  group('SigilGeometry', () {
    test('reveal and revealLength follow the written order', () {
      final g = SigilGeometry(strokes: [SigilStroke(_line(100)), SigilStroke(Path()..moveTo(0, 10)..lineTo(50, 10))]);
      expect(g.totalLength, closeTo(150, 1e-6));
      expect(g.revealLength(50).getBounds().width, closeTo(50, 0.5));
      expect(g.revealLength(120).getBounds().height, closeTo(10, 0.5));
      expect(g.reveal([1, 0]).getBounds().height, closeTo(0, 0.5));
    });
  });

  test('GeometryCache evicts least recently used', () {
    final c = GeometryCache<int>(capacity: 2);
    var builds = 0;
    int build() => ++builds;
    c.putIfAbsent('a', build);
    c.putIfAbsent('b', build);
    c.putIfAbsent('a', build); // touch a
    c.putIfAbsent('c', build); // evicts b
    expect(c.length, 2);
    c.putIfAbsent('a', build);
    expect(builds, 3);
    c.putIfAbsent('b', build);
    expect(builds, 4);
  });

  test('SeededRandom and noise are deterministic', () {
    final a = SeededRandom(42), b = SeededRandom(42);
    for (var i = 0; i < 100; i++) {
      expect(a.nextUint32(), b.nextUint32());
    }
    expect(valueNoise3(1.3, 2.7, 0.5, 7), valueNoise3(1.3, 2.7, 0.5, 7));
    for (var i = 0; i < 200; i++) {
      final v = valueNoise3(i * 0.37, i * 0.11, i * 0.05);
      expect(v, inInclusiveRange(0, 1));
    }
  });
}
