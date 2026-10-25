import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/models/intent_kernel.dart';

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
}
