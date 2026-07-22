import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_entropy.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_secp256k1.dart';

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return result;
}

Uint8List _bigIntToBytes(BigInt value, int length) {
  final result = Uint8List(length);
  var remaining = value;
  for (var i = length - 1; i >= 0; i--) {
    result[i] = (remaining & BigInt.from(0xff)).toInt();
    remaining = remaining >> 8;
  }
  return result;
}

void main() {
  group('XrplSecp256k1.deriveKeyPair', () {
    test('produces a 32-byte private key and 33-byte compressed public key',
        () {
      final entropy = XrplEntropy.fromBytes(Uint8List(16));
      final keyPair = XrplSecp256k1.deriveKeyPair(entropy);
      expect(_bigIntToBytes(keyPair.privateKey, 32).length, 32);
      expect(keyPair.compressedPublicKey.length, 33);
    });

    test('is deterministic for the same entropy', () {
      final entropy = XrplEntropy.fromBytes(
        Uint8List.fromList(List.generate(16, (i) => i)),
      );
      final a = XrplSecp256k1.deriveKeyPair(entropy);
      final b = XrplSecp256k1.deriveKeyPair(entropy);
      expect(a.privateKey, b.privateKey);
      expect(a.compressedPublicKey, b.compressedPublicKey);
    });

    test('produces different keys for different entropy', () {
      final a = XrplSecp256k1.deriveKeyPair(
        XrplEntropy.fromBytes(Uint8List(16)),
      );
      final b = XrplSecp256k1.deriveKeyPair(
        XrplEntropy.fromBytes(Uint8List.fromList(List.filled(16, 1))),
      );
      expect(a.privateKey, isNot(equals(b.privateKey)));
    });

    test(
        'matches a master key pair independently computed via the Python '
        '"ecdsa" library: root private key + intermediate private key '
        '(mod group order), and root public key + intermediate public '
        'key (EC point addition) - chained from the same root and '
        'intermediate vectors already verified in their own test files', () {
      final entropy = XrplEntropy.fromBytes(
        Uint8List.fromList(const [
          207,
          45,
          227,
          120,
          251,
          221,
          126,
          46,
          232,
          125,
          72,
          109,
          251,
          90,
          123,
          255,
        ]),
      );

      final keyPair = XrplSecp256k1.deriveKeyPair(entropy);

      expect(
        _bigIntToBytes(keyPair.privateKey, 32),
        _hexToBytes(
          '48d93a3b5948e5f9b323bf654bfad6e8'
          'ff75b5fcab03c5a55ad30cb2515b461f',
        ),
      );
      expect(
        keyPair.compressedPublicKey,
        _hexToBytes(
          '0203f2d90bc50012ec7cb20b07a1b818d6'
          '863636fb1e945d17449092cfb5495e1e',
        ),
      );
    });
  });
}
