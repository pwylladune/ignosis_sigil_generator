import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/engines/spare_monogram_engine.dart';
import 'package:ignosis_sigil_generator/src/models/intent_kernel.dart';
import 'package:ignosis_sigil_generator/src/models/sigil_state.dart';

void main() {
  test('radicals merge on the shared armature', () {
    final kernel = IntentKernel.fromText('PROTECTION AND FORCE');
    final merged = SpareMonogramEngine.mergedRadicals(kernel);
    expect(merged.toSet().length, merged.length, reason: 'no duplicates');
    expect(merged.any((r) => r.$1 == StrokeType.vertical), isFalse, reason: 'verticals merge into the spine');
    // At most 5 radical types × 3 anchors, however long the intent.
    final long = IntentKernel.fromText('BCDFGHJKLMNPQRSTVWXYZ');
    expect(SpareMonogramEngine.mergedRadicals(long).length, lessThanOrEqualTo(15));
  });

  test('group copies: Cn has n rotations, Dn adds n reflections', () {
    final c = SpareMonogramEngine.groupCopies(5, SymmetryGroup.cyclic);
    expect(c.length, 5);
    expect(c.first.angle, 0);
    expect(c.any((e) => e.mirrored), isFalse);
    final d = SpareMonogramEngine.groupCopies(5, SymmetryGroup.dihedral);
    expect(d.length, 10);
    expect(d.where((e) => e.mirrored).length, 5);
    for (var k = 0; k < 5; k++) {
      expect(c[k].angle, closeTo(2 * math.pi * k / 5, 1e-12));
    }
  });

  test('copy matrix: identity at the start, mirror then rotation at the end', () {
    const center = Offset(100, 100);
    const copy = SymmetryCopy(math.pi / 2, mirrored: true);
    final start = Path()..addPath(Path()..moveTo(10, -20)..lineTo(10, -20.001), Offset.zero, matrix4: SpareMonogramEngine.copyMatrix(copy, center, progress: 0));
    expect(start.getBounds().topLeft.dx, closeTo(110, 1e-3));
    expect(start.getBounds().topLeft.dy, closeTo(80, 1e-2));
    // Mirror (x → −x) then rotate 90°: (10, −20) → (−10, −20) → (20, −10).
    final end = Path()..addPath(Path()..moveTo(10, -20)..lineTo(10, -20.001), Offset.zero, matrix4: SpareMonogramEngine.copyMatrix(copy, center));
    expect(end.getBounds().topLeft.dx, closeTo(120, 1e-2));
    expect(end.getBounds().center.dy, closeTo(90, 1e-2));
  });

  test('assembled seal is deterministic and has n copies plus binding', () {
    const size = Size(500, 500);
    final kernel = IntentKernel.fromText('PROTECTION AND FORCE');
    final a = SpareMonogramEngine().build(kernel, size, symmetry: 4);
    final b = SpareMonogramEngine().build(IntentKernel.fromText('PROTECTION AND FORCE'), size, symmetry: 4);
    expect(a.geometry.strokes.length, a.domain.strokes.length * 4 + 1);
    expect(a.geometry.path.getBounds(), b.geometry.path.getBounds());
    final d = SpareMonogramEngine().build(kernel, size, symmetry: 4, group: SymmetryGroup.dihedral);
    expect(d.geometry.strokes.length, d.domain.strokes.length * 8 + 1);
  });
}
