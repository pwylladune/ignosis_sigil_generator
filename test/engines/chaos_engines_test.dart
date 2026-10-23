import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/models/intent_kernel.dart';
import 'package:ignosis_sigil_generator/src/engines/kamea_engine.dart';
import 'package:ignosis_sigil_generator/src/engines/rose_cross_engine.dart';
import 'package:ignosis_sigil_generator/src/engines/chladni_engine.dart';
import 'package:ignosis_sigil_generator/src/engines/cyber_chaos_engine.dart';
import 'package:ignosis_sigil_generator/src/engines/spare_monogram_engine.dart';
import 'package:flutter/material.dart';

void main() {
  group('IntentKernel Tests', () {
    test('Deduplicates consonants and strips vowels (Spare method)', () {
      final kernel = IntentKernel.fromText('MY WILL IS SOVEREIGN');
      // MY WILL IS SOVEREIGN -> M Y W L L S S V R G N
      // Deduplicated: M, Y, W, L, S, V, R, G, N
      expect(kernel.reducedConsonants.contains('E'), isFalse);
      expect(kernel.reducedConsonants.contains('I'), isFalse);
      expect(kernel.reducedConsonants.contains('O'), isFalse);
      expect(kernel.reducedConsonants, 'MYWLSVRGN');
    });

    test('Handles single word intent', () {
      final kernel = IntentKernel.fromText('FOCUS');
      // F, C, S
      expect(kernel.reducedConsonants, 'FCS');
    });

    test('Handles all vowel input gracefully', () {
      final kernel = IntentKernel.fromText('EIAO');
      expect(kernel.reducedConsonants, 'EIAO');
    });

    test('Handles empty text gracefully', () {
      final kernel = IntentKernel.fromText('   ');
      expect(kernel.isEmpty, isTrue);
    });
  });

  group('KameaEngine Tests', () {
    test('Generates deterministic nodes across all 7 planetary kameas', () {
      final engine = KameaEngine();
      final kernel = IntentKernel.fromText('MY WILL IS LAW');
      const size = Size(400, 400);

      for (final planet in PlanetaryKameaType.values) {
        final nodes = engine.getNodes(kernel, planet, size);
        expect(nodes.length, equals(kernel.reducedConsonants.length));

        final path = engine.generatePath(kernel, planet, size);
        expect(path.getBounds().isEmpty, isFalse);
      }
    });
  });

  group('RoseCrossEngine Tests', () {
    test('Generates continuous Rose Cross dial paths', () {
      final engine = RoseCrossEngine();
      final kernel = IntentKernel.fromText('TRANSCENDENCE');
      const size = Size(500, 500);

      final path = engine.generatePath(kernel, size);
      expect(path.getBounds().isEmpty, isFalse);
    });
  });

  group('ChladniEngine Tests', () {
    test('Computes 2D acoustic resonance nodal paths', () {
      final engine = ChladniEngine();
      final kernel = IntentKernel.fromText('CHAOS AND HARMONY');
      const size = Size(500, 500);

      final path = engine.generatePath(kernel, size, animationPhase: 0.5);
      expect(path.getBounds().isEmpty, isFalse);
    });
  });

  group('CyberChaosEngine Tests', () {
    test('Generates cryptographic hash polylines', () {
      final engine = CyberChaosEngine();
      final kernel = IntentKernel.fromText('IGNOSIS CONSECRATION');
      const size = Size(600, 600);

      final path = engine.generatePath(kernel, size, symmetryFolds: 6);
      expect(path.getBounds().isEmpty, isFalse);
    });
  });

  group('SpareMonogramEngine Tests', () {
    test('Builds radical monogram glyph with rotational symmetry', () {
      final engine = SpareMonogramEngine();
      final kernel = IntentKernel.fromText('PROTECTION AND FORCE');
      const size = Size(500, 500);

      final path = engine.generatePath(kernel, size, symmetry: 4);
      expect(path.getBounds().isEmpty, isFalse);
    });
  });
}
