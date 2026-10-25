import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/engines/rose_cross_engine.dart';
import 'package:ignosis_sigil_generator/src/geometry/sigil_geometry.dart';
import 'package:ignosis_sigil_generator/src/models/hebrew_letters.dart';
import 'package:ignosis_sigil_generator/src/models/intent_kernel.dart';
import 'package:ignosis_sigil_generator/src/ui/canvas/rose_scene.dart';

void main() {
  test('the rose has 3 mothers, 7 doubles and 12 simples', () {
    expect(RoseCrossEngine.rings.map((r) => r.length).toList(), [3, 7, 12]);
    expect(RoseCrossEngine.allPetals.length, 22);
    expect(RoseCrossEngine.allPetals.map((p) => p.letter).toSet().length, 22);
    expect(RoseCrossEngine.rings[0], [HebrewLetter.aleph, HebrewLetter.mem, HebrewLetter.shin]);
  });

  test('transliteration: every Latin letter reaches the rose; coverage is as documented', () {
    final latin = [for (var c = 65; c <= 90; c++) String.fromCharCode(c)];
    expect(latinToHebrew.keys.toSet(), latin.toSet());
    final reached = {for (final l in latin) RoseCrossEngine.petalFor(l).letter};
    // All three mothers are reachable (A, M, X) and so is every double.
    expect(reached.containsAll(RoseCrossEngine.rings[0]), isTrue);
    expect(reached.containsAll(RoseCrossEngine.rings[1]), isTrue);
    // Teth and Tzaddi need digraphs (Th, Tz) and are the only petals unused.
    expect(HebrewLetter.values.toSet().difference(reached), {HebrewLetter.teth, HebrewLetter.tzaddi});
    // Shared letters are the documented ones only.
    final byPetal = <HebrewLetter, List<String>>{};
    for (final l in latin) {
      byPetal.putIfAbsent(latinToHebrew[l]!, () => []).add(l);
    }
    final shared = {for (final e in byPetal.entries) if (e.value.length > 1) e.key: e.value.join()};
    expect(shared, {HebrewLetter.kaph: 'CK', HebrewLetter.yod: 'IJY', HebrewLetter.pe: 'FP', HebrewLetter.vav: 'UVW'});
  });

  test('a single letter is sealed with a terminal crossbar', () {
    final s = RoseCrossEngine().build(IntentKernel.fromText('B'), const Size(500, 500));
    expect(s.geometry.strokes.map((e) => e.role).toList(), [StrokeRole.startMark, StrokeRole.terminal]);
  });

  test('petals sit on their ring radius', () {
    const size = Size(500, 500);
    final r = RoseCrossEngine.roseRadius(size);
    for (final p in RoseCrossEngine.allPetals) {
      final pos = RoseCrossEngine.petalPosition(p, const Offset(250, 250), r);
      expect((pos - const Offset(250, 250)).distance, closeTo(r * RoseCrossEngine.ringRadii[p.ring], 1e-9));
    }
  });

  test('build follows sigil grammar and is deterministic', () {
    const size = Size(500, 500);
    final a = RoseCrossEngine().build(IntentKernel.fromText('TRANSCENDENCE'), size);
    final b = RoseCrossEngine().build(IntentKernel.fromText('TRANSCENDENCE'), size);
    expect(a.geometry.nodes, b.geometry.nodes);
    expect(a.geometry.strokes.map((s) => s.role).toList(), [StrokeRole.startMark, StrokeRole.ink, StrokeRole.terminal]);
  });

  test('astrolabe: rings move in ratio 3:7:12, counter-rotate and lock at the end', () {
    const size = Size(500, 500);
    final kernel = IntentKernel.fromText('TRANSCENDENCE');
    final scene = RoseScene(kernel, size, RoseCrossEngine().build(kernel, size), startTime: 0);
    final r0 = scene.ringRotation(0);
    expect(r0[1] / r0[0], closeTo(-7 / 3, 1e-9));
    expect(r0[2] / r0[0], closeTo(4, 1e-9));
    final end = scene.ringRotation(scene.settleTime);
    expect(end.every((a) => a.abs() < 1e-12), isTrue);
  });
}
