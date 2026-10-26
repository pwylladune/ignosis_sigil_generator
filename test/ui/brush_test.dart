import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/geometry/sigil_geometry.dart';
import 'package:ignosis_sigil_generator/src/ui/canvas/brush.dart';

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
}
