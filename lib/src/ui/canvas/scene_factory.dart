import 'dart:ui';
import '../../engines/chladni_engine.dart';
import '../../engines/cyber_chaos_engine.dart';
import '../../engines/kamea_engine.dart';
import '../../engines/rose_cross_engine.dart';
import '../../engines/spare_monogram_engine.dart';
import '../../geometry/geometry_cache.dart';
import '../../geometry/sigil_geometry.dart';
import '../../models/sigil_state.dart';
import 'scene.dart';
import 'sigil_spec.dart';

final _cache = GeometryCache<SigilGeometry>();

/// Builds the scene for [spec] at canvas [size], starting at [startTime].
///
/// [previous] lets a scene continue from the one it replaces (for example
/// Chladni sand flowing from the old mode into the new one).
SigilScene buildScene(SigilSpec spec, Size size, double startTime, {SigilScene? previous}) {
  final key = (spec, size);
  final geometry = _cache.putIfAbsent(key, () => _legacyGeometry(spec, size));
  return DuctusScene(geometry, startTime: startTime);
}

SigilGeometry _legacyGeometry(SigilSpec spec, Size size) {
  final k = spec.kernel;
  final Path path;
  switch (spec.system) {
    case SigilSystem.spare:
      path = SpareMonogramEngine().generatePath(k, size, symmetry: spec.symmetryFolds);
    case SigilSystem.kamea:
      path = KameaEngine().generatePath(k, spec.kameaType, size);
    case SigilSystem.roseCross:
      path = RoseCrossEngine().generatePath(k, size);
    case SigilSystem.chladni:
      path = ChladniEngine().generatePath(k, size);
    case SigilSystem.cyberChaos:
      path = CyberChaosEngine().generatePath(k, size, symmetryFolds: spec.symmetryFolds);
  }
  if (k.isEmpty) return SigilGeometry.empty;
  return SigilGeometry(strokes: [SigilStroke(path)]);
}
