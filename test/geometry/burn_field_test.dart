import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/geometry/burn_field.dart';
import 'package:ignosis_sigil_generator/src/geometry/sigil_geometry.dart';

void main() {
  const size = Size(400, 400);
  final geometry = SigilGeometry(strokes: [
    SigilStroke(Path()..moveTo(100, 200)..lineTo(200, 200)), // written first
    SigilStroke(Path()..moveTo(200, 100)..lineTo(200, 300)), // written last
  ]);
  final field = BurnField.compute(geometry, size);

  test('ignites at the end of the last stroke', () {
    expect(field.at(const Offset(200, 299)), lessThan(0.03));
    expect(field.sampleDistances.first, 0);
  });

  test('runs backward along the ink (reverse ductus)', () {
    // Along the last stroke, from its end toward its start, d increases.
    final a = field.at(const Offset(200, 280)), b = field.at(const Offset(200, 200)), c = field.at(const Offset(200, 110));
    expect(a, lessThan(b));
    expect(b, lessThan(c));
    // The first stroke burns after the junction with the last one.
    expect(field.at(const Offset(110, 200)), greaterThan(b));
    // Sample distances are non-decreasing from the ignition point.
    for (var i = 1; i < field.sampleDistances.length; i++) {
      expect(field.sampleDistances[i], greaterThanOrEqualTo(field.sampleDistances[i - 1]));
    }
  });

  test('ink is a fuse: fire runs along strokes faster than across paper', () {
    // Paper right next to the far end of the ink burns after that ink.
    expect(field.at(const Offset(240, 110)), greaterThan(field.at(const Offset(200, 110))));
  });

  test('values are normalised and packed as 16 bits', () {
    expect(field.values.every((v) => v >= 0 && v <= 1), isTrue);
    final rgba = field.toRgba();
    expect(rgba.length, field.resolution * field.resolution * 4);
    expect(rgba[3], 255);
  });
}
