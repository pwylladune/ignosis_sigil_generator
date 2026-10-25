import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import '../geometry/sigil_geometry.dart';
import '../models/intent_kernel.dart';
import '../models/sigil_state.dart';

/// Radical strokes of capital letters A–Z.
enum StrokeType { vertical, horizontal, diagonalUp, diagonalDown, loop, arch }

/// One copy of the fundamental domain: rotation [angle] after an optional
/// mirror across the spine.
class SymmetryCopy {
  const SymmetryCopy(this.angle, {this.mirrored = false});

  final double angle;
  final bool mirrored;
}

/// A Spare monogram: the fundamental domain (spine plus merged radicals, in
/// written order, in coordinates centred on the plate) and the group copies.
class SpareSigil {
  SpareSigil({
    required this.center,
    required this.domain,
    required this.copies,
    required this.binding,
    required this.geometry,
  });

  final Offset center;

  /// Domain strokes relative to [center].
  final SigilGeometry domain;

  /// Copies of the domain under the symmetry group; the first is the identity.
  final List<SymmetryCopy> copies;

  /// Outer binding circle, in canvas coordinates.
  final SigilStroke? binding;

  /// The assembled seal in canvas coordinates (all copies, then the binding).
  final SigilGeometry geometry;
}

/// Austin Osman Spare monogram solver.
///
/// Letters are broken into radicals, which are placed on one shared armature
/// (a spine from the bind-point outward with three anchor heights). Coincident
/// radicals merge, as Spare's own monograms share strokes; vertical radicals
/// merge into the spine itself. The resulting fundamental domain is then
/// replicated by the cyclic group Cₙ (rotations) or the dihedral group Dₙ
/// (rotations and mirror reflections).
class SpareMonogramEngine {
  static List<StrokeType> letterStrokes(String char) {
    switch (char) {
      case 'B':
        return [StrokeType.vertical, StrokeType.loop];
      case 'C':
        return [StrokeType.arch];
      case 'D':
        return [StrokeType.vertical, StrokeType.arch];
      case 'F':
        return [StrokeType.vertical, StrokeType.horizontal];
      case 'G':
        return [StrokeType.arch, StrokeType.horizontal];
      case 'H':
        return [StrokeType.vertical, StrokeType.horizontal];
      case 'J':
        return [StrokeType.vertical, StrokeType.arch];
      case 'K':
        return [StrokeType.vertical, StrokeType.diagonalUp, StrokeType.diagonalDown];
      case 'L':
        return [StrokeType.vertical, StrokeType.horizontal];
      case 'M':
      case 'W':
        return [StrokeType.vertical, StrokeType.diagonalDown, StrokeType.diagonalUp];
      case 'N':
        return [StrokeType.vertical, StrokeType.diagonalDown];
      case 'P':
        return [StrokeType.vertical, StrokeType.loop];
      case 'R':
        return [StrokeType.vertical, StrokeType.loop, StrokeType.diagonalDown];
      case 'S':
        return [StrokeType.arch];
      case 'T':
        return [StrokeType.vertical, StrokeType.horizontal];
      case 'V':
        return [StrokeType.diagonalDown, StrokeType.diagonalUp];
      case 'X':
        return [StrokeType.diagonalDown, StrokeType.diagonalUp];
      case 'Z':
        return [StrokeType.horizontal, StrokeType.diagonalDown];
      default:
        return [StrokeType.vertical, StrokeType.arch];
    }
  }

  /// Anchor heights along the spine, as fractions from the inner end.
  static const anchors = [0.3, 0.58, 0.86];

  /// Radicals of the kernel after merging, in order of first appearance, as
  /// (type, anchor index). Vertical radicals merge into the spine.
  static List<(StrokeType, int)> mergedRadicals(IntentKernel kernel) {
    final out = <(StrokeType, int)>[];
    for (var i = 0; i < kernel.length; i++) {
      final anchor = kernel.gematriaValues[i] % anchors.length;
      for (final s in letterStrokes(kernel.reducedConsonants[i])) {
        if (s == StrokeType.vertical) continue;
        final r = (s, anchor);
        if (!out.contains(r)) out.add(r);
      }
    }
    return out;
  }

  /// The group elements for [folds] and [group]; the identity comes first.
  static List<SymmetryCopy> groupCopies(int folds, SymmetryGroup group) {
    final n = folds < 1 ? 1 : folds;
    return [
      for (var k = 0; k < n; k++) SymmetryCopy(2 * math.pi * k / n),
      if (group == SymmetryGroup.dihedral)
        for (var k = 0; k < n; k++) SymmetryCopy(2 * math.pi * k / n, mirrored: true),
    ];
  }

  SpareSigil build(IntentKernel kernel, Size size, {int symmetry = 4, SymmetryGroup group = SymmetryGroup.cyclic}) {
    final center = size.center(Offset.zero);
    final scale = math.min(size.width, size.height) * 0.35;
    final copies = groupCopies(symmetry, group);
    if (kernel.isEmpty) {
      return SpareSigil(center: center, domain: SigilGeometry.empty, copies: copies, binding: null, geometry: SigilGeometry.empty);
    }

    // Spine: from near the bind-point straight up (−y), in plate-centred coordinates.
    final inner = scale * 0.14, outer = scale;
    double anchorY(int a) => -(inner + (outer - inner) * anchors[a]);

    final strokes = <SigilStroke>[
      SigilStroke(Path()
        ..moveTo(0, -inner)
        ..lineTo(0, -outer)),
    ];
    for (final (type, a) in mergedRadicals(kernel)) {
      final y = anchorY(a);
      final p = Path();
      switch (type) {
        case StrokeType.horizontal:
          p
            ..moveTo(-scale * 0.16, y)
            ..lineTo(scale * 0.16, y);
        case StrokeType.diagonalDown:
          p
            ..moveTo(0, y)
            ..lineTo(scale * 0.2, y + scale * 0.14);
        case StrokeType.diagonalUp:
          p
            ..moveTo(0, y)
            ..lineTo(-scale * 0.2, y - scale * 0.14);
        case StrokeType.loop:
          p.addOval(Rect.fromCircle(center: Offset(scale * 0.09, y), radius: scale * 0.09));
        case StrokeType.arch:
          p.addArc(Rect.fromCircle(center: Offset(0, y), radius: scale * 0.13), -math.pi / 2, math.pi);
        case StrokeType.vertical:
          continue;
      }
      strokes.add(SigilStroke(p));
    }
    final domain = SigilGeometry(strokes: strokes);

    final binding = SigilStroke(Path()..addOval(Rect.fromCircle(center: center, radius: scale * 1.15)), role: StrokeRole.binding);

    final assembled = <SigilStroke>[
      for (final c in copies)
        for (final s in strokes) SigilStroke(s.path.transform(copyMatrix(c, center))),
      binding,
    ];

    return SpareSigil(center: center, domain: domain, copies: copies, binding: binding, geometry: SigilGeometry(strokes: assembled));
  }

  /// Column-major 4×4 matrix: translate to [center] · rotate · optional mirror.
  static Float64List copyMatrix(SymmetryCopy c, Offset center, {double progress = 1}) {
    final a = c.angle * progress;
    final sx = c.mirrored ? 1 - 2 * progress : 1.0;
    final cos = math.cos(a), sin = math.sin(a);
    return Float64List.fromList([
      cos * sx, sin * sx, 0, 0, //
      -sin, cos, 0, 0,
      0, 0, 1, 0,
      center.dx, center.dy, 0, 1,
    ]);
  }
}
