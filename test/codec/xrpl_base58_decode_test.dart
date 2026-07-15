import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/codec/xrpl_base58.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';

void main() {
  group('XrplBase58.decodeRaw', () {
    test('returns empty bytes for empty input', () {
      expect(XrplBase58.decodeRaw(''), Uint8List(0));
    });

    test('decodes a single-character result back to its byte', () {
      // 'p' is alphabet index 1, matching the encodeRaw([1]) test.
      expect(XrplBase58.decodeRaw('p'), Uint8List.fromList([1]));
    });

    test('decodes leading alphabet[0] characters back to zero bytes', () {
      expect(
        XrplBase58.decodeRaw('rrp'),
        Uint8List.fromList([0, 0, 1]),
      );
    });

    test('all alphabet[0] input decodes to all-zero bytes', () {
      expect(XrplBase58.decodeRaw('rrrr'), Uint8List.fromList([0, 0, 0, 0]));
    });

    test('throws XrplCryptoException on a character outside the alphabet', () {
      // '0' (zero) is intentionally excluded from the XRPL alphabet.
      expect(
        () => XrplBase58.decodeRaw('p0p'),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('error message identifies the offending character and position', () {
      try {
        XrplBase58.decodeRaw('pO');
        fail('Expected an XrplCryptoException');
      } on XrplCryptoException catch (e) {
        expect(e.message, contains('O'));
        expect(e.message, contains('1'));
      }
    });

    group('round-trip with encodeRaw', () {
      for (final bytes in [
        <int>[1, 2, 3, 4, 5],
        <int>[0, 1, 2, 3],
        <int>[0, 0, 0, 42],
        List<int>.filled(4, 0),
        List<int>.generate(32, (i) => i * 7 % 256),
      ]) {
        test('recovers the original bytes for $bytes', () {
          final data = Uint8List.fromList(bytes);
          final encoded = XrplBase58.encodeRaw(data);
          final decoded = XrplBase58.decodeRaw(encoded);
          expect(decoded, data);
        });
      }
    });
  });
}
