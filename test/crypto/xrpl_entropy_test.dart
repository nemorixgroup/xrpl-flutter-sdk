import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_entropy.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';

void main() {
  group('XrplEntropy.generate', () {
    test('produces exactly 16 bytes', () {
      final entropy = XrplEntropy.generate();
      expect(entropy.bytes.length, 16);
    });

    test('produces different entropy on each call', () {
      final first = XrplEntropy.generate();
      final second = XrplEntropy.generate();
      expect(first.bytes, isNot(equals(second.bytes)));
    });

    test('produces non-trivial entropy (not all zero bytes)', () {
      final entropy = XrplEntropy.generate();
      expect(entropy.bytes.every((b) => b == 0), isFalse);
    });
  });

  group('XrplEntropy.fromBytes', () {
    test('accepts exactly 16 bytes', () {
      final bytes = Uint8List.fromList(List.generate(16, (i) => i));
      final entropy = XrplEntropy.fromBytes(bytes);
      expect(entropy.bytes, equals(bytes));
    });

    test('rejects fewer than 16 bytes', () {
      final bytes = Uint8List(8);
      expect(
        () => XrplEntropy.fromBytes(bytes),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('rejects more than 16 bytes', () {
      final bytes = Uint8List(32);
      expect(
        () => XrplEntropy.fromBytes(bytes),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('error message reports the actual length received', () {
      final bytes = Uint8List(8);
      try {
        XrplEntropy.fromBytes(bytes);
        fail('Expected an XrplCryptoException');
      } on XrplCryptoException catch (e) {
        expect(e.message, contains('16'));
        expect(e.message, contains('8'));
      }
    });

    test('does not share reference with the original list', () {
      final original = Uint8List(16);
      final entropy = XrplEntropy.fromBytes(original);
      original[0] = 42;
      expect(entropy.bytes[0], isNot(42));
    });
  });

  group('XrplEntropy.validate', () {
    test('does not throw for valid length', () {
      expect(() => XrplEntropy.validate(Uint8List(16)), returnsNormally);
    });

    test('throws for invalid length', () {
      expect(
        () => XrplEntropy.validate(Uint8List(1)),
        throwsA(isA<XrplCryptoException>()),
      );
    });
  });
}
