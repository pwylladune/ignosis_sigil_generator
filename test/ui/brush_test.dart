import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/geometry/sigil_geometry.dart';
import 'package:ignosis_sigil_generator/src/ui/canvas/brush.dart';
import 'package:ignosis_sigil_generator/src/ui/canvas/scene.dart';

void main() {
  test('an ink stroke lands, swells and sweeps out to a fine point', () {
    final b = BrushStroke.of(SigilStroke(Path()..moveTo(0, 0)..lineTo(200, 0)));
    final land = b.pressureAt(0.0), belly = b.pressureAt(0.3), tail = b.pressureAt(1.0);
    expect(land, lessThan(belly), reason: 'brush presses in');
    expect(tail, lessThan(0.1), reason: 'harai: sweeps out to a point');
    // The minimum-jerk pen is fastest mid-stroke, where the brush lifts a little.
    expect(b.pressureAt(0.5), lessThan(b.pressureAt(0.2) * 1.05));
  });

  test('a terminal crossbar flicks (hane)', () {
    final b = BrushStroke.of(SigilStroke(Path()..moveTo(0, 0)..lineTo(30, 0), role: StrokeRole.terminal));
    expect(b.pressureAt(0.2), greaterThan(b.pressureAt(0.95)));
  });

  test('sharp turns split the stroke so the brush re-presses at corners', () {
    final straight = BrushStroke.of(SigilStroke(Path()..moveTo(0, 0)..lineTo(100, 0)..lineTo(200, 0)));
    final zigzag = BrushStroke.of(SigilStroke(Path()..moveTo(0, 0)..lineTo(100, 0)..lineTo(100, 100)..lineTo(0, 100)));
    expect(straight.segmentCount, 1);
    expect(zigzag.segmentCount, 3);
  });

  test('brushwork is deterministic for the same geometry', () {
    Path p() => Path()..moveTo(10, 20)..quadraticBezierTo(80, 0, 150, 60);
    final a = BrushStroke.of(SigilStroke(p())), b = BrushStroke.of(SigilStroke(p()));
    for (final u in [0.0, 0.1, 0.33, 0.5, 0.8, 1.0]) {
      expect(a.pressureAt(u), b.pressureAt(u));
    }
  });

  test('with a seed, brushwork stays put while the stroke moves (Rose rings)', () {
    Path at(double dx) => Path()..moveTo(10 + dx, 20)..quadraticBezierTo(80 + dx, 0, 150 + dx, 60);
    // Without a seed, the brush is seeded from position: a moved stroke re-rolls.
    final moved = [for (final dx in [0.0, 3.0]) BrushStroke.of(SigilStroke(at(dx)))];
    final rerolled = [0.1, 0.4, 0.7].any((u) => moved[0].pressureAt(u) != moved[1].pressureAt(u));
    expect(rerolled, isTrue);
    // With a seed, the same brushwork follows the stroke.
    final seeded = [for (final dx in [0.0, 3.0]) BrushStroke.of(SigilStroke(at(dx)), seed: 4242)];
    for (final u in [0.0, 0.1, 0.4, 0.7, 1.0]) {
      expect(seeded[0].pressureAt(u), seeded[1].pressureAt(u));
    }
  });

  test('a settled stroke builds its outline once per width step, not once per breathing frame', () {
    const skin = SceneStyle(
      ink: Color(0xFF141416),
      guide: Color(0xFF888888),
      muted: Color(0xFF888888),
      secondary: Color(0xFF555555),
      accent: Color(0xFF333333),
      seal: Color(0xFFC0392B),
      burn: Color(0xFFC0392B),
      paper: Color(0xFFF4F4F0),
      strokeWidth: 2,
      washOpacity: 0.1,
    );
    SceneStyle breathing(double breath) => SceneStyle(
          ink: skin.ink,
          guide: skin.guide,
          muted: skin.muted,
          secondary: skin.secondary,
          accent: skin.accent,
          seal: skin.seal,
          burn: skin.burn,
          paper: skin.paper,
          strokeWidth: skin.strokeWidth,
          washOpacity: skin.washOpacity,
          breath: breath,
        );
    expect(breathing(0).brushWidth, closeTo(skin.brushWidth * 0.97, 1e-9));
    expect(breathing(1).brushWidth, closeTo(skin.brushWidth * 1.03, 1e-9));

    final stroke = BrushStroke.of(SigilStroke(Path()..moveTo(0, 0)..lineTo(200, 0)));
    final canvas = Canvas(PictureRecorder());
    final before = BrushStroke.outlinesBuilt;
    // Four seconds of Gnosis at 60 frames a second.
    for (var frame = 0; frame < 240; frame++) {
      final style = breathing(0.5 + 0.5 * math.sin(frame / 240 * 2 * math.pi));
      stroke.paint(canvas, style, 1, style.brushWidth);
    }
    expect(BrushStroke.outlinesBuilt - before, lessThanOrEqualTo(13));

    // A stroke still being written is rebuilt as it grows.
    final writing = BrushStroke.of(SigilStroke(Path()..moveTo(0, 50)..lineTo(200, 50)));
    final start = BrushStroke.outlinesBuilt;
    for (var frame = 1; frame <= 10; frame++) {
      writing.paint(canvas, skin, frame / 20, 8.4);
    }
    expect(BrushStroke.outlinesBuilt - start, 10);
  });
}
