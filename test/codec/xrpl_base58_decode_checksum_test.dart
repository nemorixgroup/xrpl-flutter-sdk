import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/codec/xrpl_base58.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';

void main() {
  group('XrplBase58.decodeWithChecksum', () {
    test('round-trips correctly with encodeWithChecksum', () {
      final data = Uint8List.fromList([0x21, 10, 20, 30, 40]);
      final encoded = XrplBase58.encodeWithChecksum(data);
      final decoded = XrplBase58.decodeWithChecksum(encoded);
      expect(decoded, data);
    });

    test('round-trips correctly with data that has leading zero bytes', () {
      final data = Uint8List.fromList([0, 0, 5, 6, 7]);
      final encoded = XrplBase58.encodeWithChecksum(data);
      final decoded = XrplBase58.decodeWithChecksum(encoded);
      expect(decoded, data);
    });

    test('detects a single mistyped character (the real-world scenario)', () {
      final data = Uint8List.fromList([0x21, 1, 2, 3, 4, 5]);
      final validEncoded = XrplBase58.encodeWithChecksum(data);

      // Flip the last character to simulate a typo.
      final lastChar = validEncoded[validEncoded.length - 1];
      final replacement =
          XrplBase58.alphabet.split('').firstWhere((c) => c != lastChar);
      final withTypo =
          validEncoded.substring(0, validEncoded.length - 1) + replacement;

      expect(
        () => XrplBase58.decodeWithChecksum(withTypo),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('error message clearly indicates a checksum mismatch', () {
      final data = Uint8List.fromList([0x21, 1, 2, 3]);
      final validEncoded = XrplBase58.encodeWithChecksum(data);
      final lastChar = validEncoded[validEncoded.length - 1];
      final replacement =
          XrplBase58.alphabet.split('').firstWhere((c) => c != lastChar);
      final withTypo =
          validEncoded.substring(0, validEncoded.length - 1) + replacement;

      try {
        XrplBase58.decodeWithChecksum(withTypo);
        fail('Expected an XrplCryptoException');
      } on XrplCryptoException catch (e) {
        expect(e.message, contains('Checksum mismatch'));
      }
    });

    test('rejects input too short to contain a checksum', () {
      // Encodes to fewer than 4 raw bytes once decoded.
      final tooShort = XrplBase58.encodeRaw(Uint8List.fromList([1, 2]));
      expect(
        () => XrplBase58.decodeWithChecksum(tooShort),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('propagates invalid-character errors from decodeRaw', () {
      expect(
        () => XrplBase58.decodeWithChecksum('p0p0'),
        throwsA(isA<XrplCryptoException>()),
      );
    });
  });
}
