import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../engines/spare_monogram_engine.dart';
import '../../geometry/sigil_geometry.dart';
import '../../motion/ductus.dart';
import '../../motion/easing.dart';
import 'scene.dart';

/// Group assembly. The fundamental domain is written in kernel order (ductus),
/// then the symmetry group builds the seal: each rotated copy turns out from
/// angle 0 to its place 2πk/n with staggered minimum-jerk starts, and in Dₙ
/// each mirrored copy flips over the spine as it turns. Finally the binding
/// circle is drawn, and the seal is still.
class SpareScene extends SigilScene {
  SpareScene(this.sigil, {required super.startTime})
      : domainTimeline = DuctusTimeline(sigil.domain),
        // The binding circle is a single sweep, drawn faster than the glyph.
        bindingTimeline = DuctusTimeline(SigilGeometry(strokes: [if (sigil.binding != null) sigil.binding!]), penSpeed: 950) {
    final n = sigil.copies.length;
    _assemblyStart = domainTimeline.duration + 0.15;
    _assemblyEnd = _assemblyStart + (n <= 1 ? 0 : (n - 2) * _stagger + _turn);
  }

  final SpareSigil sigil;
  final DuctusTimeline domainTimeline;
  final DuctusTimeline bindingTimeline;
  late final double _assemblyStart;
  late final double _assemblyEnd;

  static const _stagger = 0.12;
  static const _turn = 0.9;

  @override
  SigilGeometry get geometry => sigil.geometry;

  @override
  double get settleTime => sigil.geometry.isEmpty ? 0 : _assemblyEnd + 0.1 + bindingTimeline.duration;

  @override
  void paint(Canvas canvas, Size size, double now, SceneStyle style) {
    if (sigil.geometry.isEmpty) return;
    final t = math.min(now - startTime, settleTime);
    final domain = sigil.domain.strokes;
    final all = List.filled(domain.length, 1.0);

    // Every copy carries the same brushwork, painted under its group element,
    // so the symmetry is exact down to the dry-brush streaks.
    void paintCopy(int k, List<double> fractions, {double progress = 1}) {
      canvas.save();
      canvas.transform(SpareMonogramEngine.copyMatrix(sigil.copies[k], sigil.center, progress: progress));
      style.drawStrokes(canvas, domain, fractions);
      canvas.restore();
    }

    // 1. Write the fundamental domain.
    paintCopy(0, t >= domainTimeline.duration ? all : domainTimeline.fractionsAt(t));

    // 2. The group acts: copies turn (and flip) out of the identity.
    if (t >= _assemblyStart) {
      for (var k = 1; k < sigil.copies.length; k++) {
        paintCopy(k, all, progress: minimumJerkBetween(t, _assemblyStart + (k - 1) * _stagger, _turn));
      }
    }

    // 3. Bind.
    final tb = t - _assemblyEnd - 0.1;
    if (tb > 0 && sigil.binding != null) {
      style.drawStrokes(canvas, [sigil.binding!], bindingTimeline.fractionsAt(tb));
    }
  }
}
