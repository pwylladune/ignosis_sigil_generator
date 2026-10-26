import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/engines/ring_cipher_engine.dart';
import 'package:ignosis_sigil_generator/src/models/intent_kernel.dart';

void main() {
  const size = Size(500, 500);

  test('wheel layout matches the drawn sheet', () {
    expect(RingCipherEngine.spokeCount, 28);
    Offset dir(String l) {
      final a = RingCipherEngine.spokeAngle(RingCipherEngine.alphabet.indexOf(l));
      return Offset(math.cos(a), math.sin(a));
    }
    // A just above 9 o'clock, N just above 3 o'clock, G/H straddle the top.
    expect(dir('A').dx, lessThan(-0.95));
    expect(dir('A').dy, lessThan(0));
    expect(dir('N').dx, greaterThan(0.95));
    expect(dir('N').dy, lessThan(0));
    expect(dir('G').dx, lessThan(0));
    expect(dir('H').dx, greaterThan(0));
    expect(dir('G').dy, closeTo(dir('H').dy, 1e-12));
    // ',' then '.' run back up the left side to A.
    expect(dir(',').dx, lessThan(-0.9));
    expect(dir('.').dy, greaterThan(0));
  });

  test('phrase keeps letters, commas and full stops; skips the rest', () {
    expect(RingCipherEngine.cipherText('My will, done.'), 'MYWILL,DONE.');
  });

  test('each step goes the short way; a half-turn goes clockwise', () {
    final a = RingCipherEngine.alphabet.indexOf;
    expect(RingCipherEngine.shortestSteps(a('A'), a('C')), 2); // clockwise
    expect(RingCipherEngine.shortestSteps(a('C'), a('A')), -2); // anticlockwise
    expect(RingCipherEngine.shortestSteps(a('A'), a('.')), -1); // wraps the short way
    expect(RingCipherEngine.shortestSteps(a('A'), a('O')), 14); // exact half: clockwise
  });

  test('arcs climb one ring per letter pair, from letter to next letter', () {
    final arcs = RingCipherEngine.arcsFor('ABCA');
    expect(arcs.map((r) => r.ring).toList(), [0, 1, 2]);
    expect(arcs.map((r) => (r.from, r.to)).toList(), [(0, 1), (1, 2), (2, 0)]);
    expect(arcs.last.sweep, closeTo(-2 * RingCipherEngine.step, 1e-12));
  });

  test('a doubled letter leaves a notch and still steps out', () {
    final s = RingCipherEngine().build(IntentKernel.fromText('WILL'), size);
    expect(s.arcs.length, 3);
    expect(s.arcs[2].sweep, 0);
    expect(s.geometry.strokes[2].length, greaterThan(0));
  });

  test('a single letter still leaves a mark; empty leaves none', () {
    expect(RingCipherEngine().build(IntentKernel.fromText('A'), size).geometry.strokes.length, 1);
    expect(RingCipherEngine().build(IntentKernel.fromText(''), size).geometry.isEmpty, isTrue);
  });

  test('arcs start on the first letter spoke of their ring', () {
    final s = RingCipherEngine().build(IntentKernel.fromText('DOG'), size);
    final first = s.geometry.strokes.first.pointAt(0)!;
    final a = RingCipherEngine.spokeAngle(RingCipherEngine.alphabet.indexOf('D'));
    final r = s.ringRadius(0);
    expect((first - (s.center + Offset(math.cos(a), math.sin(a)) * r)).distance, lessThan(0.5));
    // Each later arc sits further out.
    expect(s.ringRadius(1), greaterThan(s.ringRadius(0)));
  });

  test('deterministic', () {
    final a = RingCipherEngine().build(IntentKernel.fromText('I COMMAND RADIANT CLARITY'), size);
    final b = RingCipherEngine().build(IntentKernel.fromText('I COMMAND RADIANT CLARITY'), size);
    expect(a.arcs.map((x) => x.sweep).toList(), b.arcs.map((x) => x.sweep).toList());
  });
}
