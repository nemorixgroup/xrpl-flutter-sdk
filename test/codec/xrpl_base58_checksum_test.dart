import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/codec/xrpl_base58.dart';

void main() {
  group('XrplBase58.checksumOf', () {
    test('matches an independently computed double-SHA256 vector', () {
      // Computed independently via Python's hashlib for
      // data = [1, 2, 3, 4, 5]:
      //   sha256(sha256(data))[:4] == [162, 107, 175, 90]
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final checksum = XrplBase58.checksumOf(data);
      expect(checksum, Uint8List.fromList([162, 107, 175, 90]));
    });

    test('is always exactly 4 bytes', () {
      expect(XrplBase58.checksumOf(Uint8List.fromList([9])).length, 4);
      expect(
        XrplBase58.checksumOf(Uint8List.fromList(List.filled(50, 7))).length,
        4,
      );
    });

    test('is deterministic for the same input', () {
      final data = Uint8List.fromList([5, 4, 3, 2, 1]);
      expect(XrplBase58.checksumOf(data), XrplBase58.checksumOf(data));
    });

    test('differs for different input', () {
      final a = XrplBase58.checksumOf(Uint8List.fromList([1, 2, 3]));
      final b = XrplBase58.checksumOf(Uint8List.fromList([1, 2, 4]));
      expect(a, isNot(equals(b)));
    });
  });

  group('XrplBase58.encodeWithChecksum', () {
    test('matches encodeRaw applied to data + checksum', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final expected = XrplBase58.encodeRaw(
        Uint8List.fromList([...data, ...XrplBase58.checksumOf(data)]),
      );
      expect(XrplBase58.encodeWithChecksum(data), expected);
    });

    test('produces a different (longer-input) result than encodeRaw alone', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      expect(
        XrplBase58.encodeWithChecksum(data),
        isNot(equals(XrplBase58.encodeRaw(data))),
      );
    });

    test('only uses characters from the XRPL alphabet', () {
      final data = Uint8List.fromList([0x21, 10, 20, 30, 40]);
      final result = XrplBase58.encodeWithChecksum(data);
      for (final char in result.split('')) {
        expect(XrplBase58.alphabet.contains(char), isTrue);
      }
    });

    test('is deterministic for the same input', () {
      final data = Uint8List.fromList([0x21, 1, 2, 3]);
      expect(
        XrplBase58.encodeWithChecksum(data),
        XrplBase58.encodeWithChecksum(data),
      );
    });
  });
}
