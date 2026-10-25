import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/models/intent_kernel.dart';

void main() {
  group('IntentKernel Tests', () {
    test('Optional vowel stripping (modern convention)', () {
      final kernel = IntentKernel.fromText('MY WILL IS SOVEREIGN', stripVowels: true);
      // MY WILL IS SOVEREIGN -> M Y W L L S S V R G N
      // Deduplicated: M, Y, W, L, S, V, R, G, N
      expect(kernel.reducedConsonants.contains('E'), isFalse);
      expect(kernel.reducedConsonants.contains('I'), isFalse);
      expect(kernel.reducedConsonants.contains('O'), isFalse);
      expect(kernel.reducedConsonants, 'MYWLSVRGN');
    });

    test('Handles single word intent', () {
      final kernel = IntentKernel.fromText('FOCUS', stripVowels: true);
      // F, C, S
      expect(kernel.reducedConsonants, 'FCS');
    });

    test('Default is Carroll: repeated letters struck out, vowels kept', () {
      expect(IntentKernel.fromText('MY WILL IS SOVEREIGN').reducedConsonants, 'MYWILSOVERGN');
      expect(IntentKernel.fromText('FOCUS').reducedConsonants, 'FOCUS');
    });

    test('Handles all vowel input gracefully', () {
      final kernel = IntentKernel.fromText('EIAO', stripVowels: true);
      expect(kernel.reducedConsonants, 'EIAO');
    });

    test('Handles empty text gracefully', () {
      final kernel = IntentKernel.fromText('   ');
      expect(kernel.isEmpty, isTrue);
    });
  });
}
