import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_hash.dart';

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return result;
}

void main() {
  group('XrplHash.sha512Half', () {
    test('is always exactly 32 bytes', () {
      expect(XrplHash.sha512Half(Uint8List(0)).length, 32);
      expect(XrplHash.sha512Half(Uint8List(20)).length, 32);
      expect(XrplHash.sha512Half(Uint8List(41)).length, 32);
    });

    test('matches an independently computed vector for "abc"', () {
      // Computed independently via Python's hashlib:
      //   sha512("abc").hexdigest()[:64] (first 32 bytes)
      final input = Uint8List.fromList('abc'.codeUnits);
      final result = XrplHash.sha512Half(input);
      expect(
        result,
        _hexToBytes(
          'ddaf35a193617abacc417349ae204131'
          '12e6fa4e89a97ea20a9eeee64b55d39a',
        ),
      );
    });

    test(
        'matches an independently computed vector for '
        '16 zero bytes + a 4-byte zero sequence (the shape used in '
        'secp256k1 root key derivation)', () {
      // Computed independently via Python's hashlib for
      // 20 zero bytes total (16-byte seed + 4-byte sequence, both 0).
      final input = Uint8List(20);
      final result = XrplHash.sha512Half(input);
      expect(
        result,
        _hexToBytes(
          'd296b892b3a7964bd0cc882fc7c0be94'
          '8b6bbd8eb1eff8c13942fcaabf1f3877',
        ),
      );
    });

    test('is deterministic for the same input', () {
      final input = Uint8List.fromList([1, 2, 3, 4, 5]);
      expect(
        XrplHash.sha512Half(input),
        XrplHash.sha512Half(input),
      );
    });

    test('differs for different input', () {
      final a = XrplHash.sha512Half(Uint8List.fromList([1, 2, 3]));
      final b = XrplHash.sha512Half(Uint8List.fromList([1, 2, 4]));
      expect(a, isNot(equals(b)));
    });
  });
}
