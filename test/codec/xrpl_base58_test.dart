import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/codec/xrpl_base58.dart';

void main() {
  group('XrplBase58.encodeRaw', () {
    test('returns empty string for empty input', () {
      expect(XrplBase58.encodeRaw(Uint8List(0)), '');
    });

    test('encodes a single non-zero byte', () {
      // 1 -> index 1 in the XRPL alphabet ('p')
      final result = XrplBase58.encodeRaw(Uint8List.fromList([1]));
      expect(result, 'p');
    });

    test('encodes multiple bytes without leading zeros', () {
      final result = XrplBase58.encodeRaw(Uint8List.fromList([1, 2, 3]));
      expect(result, isNotEmpty);
      expect(result, isNot(contains('0')));
      expect(result, isNot(contains('O')));
      expect(result, isNot(contains('I')));
      expect(result, isNot(contains('l')));
    });

    test('preserves a single leading zero byte as alphabet[0]', () {
      final withZero = XrplBase58.encodeRaw(Uint8List.fromList([0, 5]));
      final withoutZero = XrplBase58.encodeRaw(Uint8List.fromList([5]));
      expect(withZero, '${XrplBase58.alphabet[0]}$withoutZero');
    });

    test('preserves multiple leading zero bytes', () {
      final result = XrplBase58.encodeRaw(
        Uint8List.fromList([0, 0, 0, 42]),
      );
      expect(result.startsWith('rrr'), isTrue);
    });

    test('all-zero input encodes to alphabet[0] repeated', () {
      final result = XrplBase58.encodeRaw(Uint8List(4));
      expect(result, 'r' * 4);
    });

    test('different inputs produce different outputs', () {
      final a = XrplBase58.encodeRaw(Uint8List.fromList([10, 20, 30]));
      final b = XrplBase58.encodeRaw(Uint8List.fromList([10, 20, 31]));
      expect(a, isNot(equals(b)));
    });

    test('only uses characters from the XRPL alphabet', () {
      final result = XrplBase58.encodeRaw(
        Uint8List.fromList(List.generate(32, (i) => i * 7 % 256)),
      );
      for (final char in result.split('')) {
        expect(XrplBase58.alphabet.contains(char), isTrue);
      }
    });
  });
}
