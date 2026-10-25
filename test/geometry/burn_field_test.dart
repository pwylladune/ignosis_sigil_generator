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
    expect(field.at(const Offset(200, 299)), lessThan(0.02));
  });

  test('runs backward along the ink (reverse ductus) and branches at junctions', () {
    final a = field.at(const Offset(200, 280)), b = field.at(const Offset(200, 200)), c = field.at(const Offset(200, 110));
    expect(a, lessThan(b));
    expect(b, lessThan(c));
    expect(field.at(const Offset(110, 200)), greaterThan(b));
  });

  test('ink is a fuse: fire runs along strokes faster than across paper', () {
    expect(field.at(const Offset(240, 110)), greaterThan(field.at(const Offset(200, 110))));
    // Far end of the first stroke (100 px of ink from the junction) burns well
    // before paper the same distance from the junction.
    expect(field.at(const Offset(102, 200)), lessThan(field.at(const Offset(200, 200)) + 0.1));
    expect(field.at(const Offset(300, 200)), greaterThan(field.at(const Offset(102, 200))));
  });

  test('depends only on where the ink is, not how strokes are grouped', () {
    final separate = SigilGeometry(strokes: [
      SigilStroke(Path()..moveTo(80, 120)..lineTo(130, 120)),
      SigilStroke(Path()..moveTo(270, 280)..lineTo(320, 280)),
    ]);
    final grouped = SigilGeometry(strokes: [
      SigilStroke(Path()
        ..moveTo(80, 120)
        ..lineTo(130, 120)
        ..moveTo(270, 280)
        ..lineTo(320, 280)),
    ]);
    final a = BurnField.compute(separate, size), b = BurnField.compute(grouped, size);
    expect(a.values, b.values);
    // The disconnected segment is reached only by crossing paper.
    expect(a.at(const Offset(100, 120)), greaterThan(0.5));
  });

  test('16-bit packing round-trips through the shader decode', () {
    for (var v = 0; v <= 65535; v += 97) {
      final x = v / 65535;
      final e = BurnField.encode(x);
      final decoded = BurnField.decode((e >> 8) / 255, (e & 0xFF) / 255);
      expect(decoded, closeTo(x, 1e-9));
    }
    expect(BurnField.decode(0, 255 / 255), isNot(closeTo(BurnField.decode(1 / 255, 0), 1e-9)));
    expect(field.toRgba().length, field.resolution * field.resolution * 4);
  });

  test('zero-size canvas does not throw', () {
    final f = BurnField.compute(geometry, Size.zero);
    expect(f.samples, isEmpty);
    expect(f.at(Offset.zero), 0);
  });
}
