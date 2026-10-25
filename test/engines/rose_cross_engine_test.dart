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
    expect(RoseCrossEngine.allPetals.map((p) => p.letter).toSet(), HebrewLetter.values.toSet());
    for (var r = 0; r < 3; r++) {
      final cls = [LetterClass.mother, LetterClass.double, LetterClass.simple][r];
      expect(RoseCrossEngine.rings[r].every((l) => l.letterClass == cls), isTrue);
    }
  });

  test('lamen layout: Aleph and He at the top, zodiac anticlockwise, planets straddling the top', () {
    const c = Offset(250, 250);
    Offset at(HebrewLetter l) => RoseCrossEngine.petalPosition(RoseCrossEngine.petalOf(l), c, 200);
    // Inner: Aleph at the top, then Shin clockwise (to the right).
    expect(at(HebrewLetter.aleph).dx, closeTo(250, 1e-9));
    expect(at(HebrewLetter.aleph).dy, lessThan(250));
    expect(at(HebrewLetter.shin).dx, greaterThan(250));
    // Outer: He (Aries) at the top, Vav (Taurus) next anticlockwise (to the left),
    // Lamed (Libra) at the bottom, Qoph (Pisces) just right of the top.
    expect(at(HebrewLetter.he).dx, closeTo(250, 1e-9));
    expect(at(HebrewLetter.vav).dx, lessThan(250));
    expect(at(HebrewLetter.lamed).dy, greaterThan(250));
    expect(at(HebrewLetter.lamed).dx, closeTo(250, 1e-6));
    expect(at(HebrewLetter.qoph).dx, greaterThan(250));
    // Middle: Pe at 11 o'clock and Kaph at 1 o'clock, symmetric about the top.
    expect(at(HebrewLetter.pe).dx, lessThan(250));
    expect(at(HebrewLetter.kaph).dx, greaterThan(250));
    expect(at(HebrewLetter.pe).dy, closeTo(at(HebrewLetter.kaph).dy, 1e-9));
  });

  test('transliteration (Golden Dawn / 777): digraphs first, every letter reachable', () {
    String spell(String s) => transliterate(s).map((l) => l.title).join('-');
    expect(spell('SHT'), 'Shin-Teth');
    expect(spell('THE'), 'Tav-He');
    expect(spell('CHAOS'), 'Heth-Aleph-Ayin-Samekh');
    expect(spell('HE'), 'He-He');
    expect(spell('PHX'), 'Pe-Samekh');
    expect(spell('TZADDI'), 'Tzaddi-Aleph-Daleth-Daleth-Yod');
    final reached = <HebrewLetter>{
      for (var c = 65; c <= 90; c++) ...transliterate(String.fromCharCode(c)),
      for (final d in latinDigraphs.keys) ...transliterate(d),
    };
    expect(reached, HebrewLetter.values.toSet());
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
