import 'dart:ui';
import '../../engines/chladni_engine.dart';
import '../../engines/cyber_chaos_engine.dart';
import '../../engines/kamea_engine.dart';
import '../../engines/rose_cross_engine.dart';
import '../../engines/spare_monogram_engine.dart';
import '../../geometry/geometry_cache.dart';
import '../../models/sigil_state.dart';
import 'chaos_scene.dart';
import 'chladni_scene.dart';
import 'kamea_scene.dart';
import 'rose_scene.dart';
import 'scene.dart';
import 'spare_scene.dart';
import 'sigil_spec.dart';

final _kameaCache = GeometryCache<KameaSigil>();
final _chladniCache = GeometryCache<ChladniSigil>();
final _roseCache = GeometryCache<RoseSigil>();
final _spareCache = GeometryCache<SpareSigil>(capacity: 12);
final _chaosCache = GeometryCache<ChaosSigil>(capacity: 8);

/// Builds the scene for [spec] at canvas [size], starting at [startTime].
///
/// [previous] lets a scene continue from the one it replaces (for example
/// Chladni sand flowing from the old mode into the new one).
SigilScene buildScene(SigilSpec spec, Size size, double startTime, {SigilScene? previous}) {
  final key = (spec, size);
  switch (spec.system) {
    case SigilSystem.kamea:
      final sigil = _kameaCache.putIfAbsent(key, () => KameaEngine().build(spec.kernel, spec.kameaType, size));
      return KameaScene(sigil, startTime: startTime);
    case SigilSystem.chladni:
      final sigil = _chladniCache.putIfAbsent(key, () => ChladniEngine().build(spec.kernel, size));
      return ChladniScene(sigil, startTime: startTime, previous: previous is ChladniScene ? previous : null);
    case SigilSystem.roseCross:
      final sigil = _roseCache.putIfAbsent(key, () => RoseCrossEngine().build(spec.kernel, size));
      return RoseScene(spec.kernel, size, sigil, startTime: startTime);
    case SigilSystem.cyberChaos:
      final sigil = _chaosCache.putIfAbsent(key, () => CyberChaosEngine().build(spec.kernel, size, symmetryFolds: spec.symmetryFolds));
      return ChaosScene(sigil, startTime: startTime);
    case SigilSystem.spare:
      final sigil = _spareCache.putIfAbsent(
          key, () => SpareMonogramEngine().build(spec.kernel, size, symmetry: spec.symmetryFolds, group: spec.symmetryGroup));
      return SpareScene(sigil, startTime: startTime);
  }
}
