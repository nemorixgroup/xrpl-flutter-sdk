import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_entropy.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_secp256k1.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';

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
  group('XrplSecp256k1.deriveIntermediateKeyPair', () {
    test('throws when rootPublicKey is not exactly 33 bytes', () {
      expect(
        () => XrplSecp256k1.deriveIntermediateKeyPair(Uint8List(10)),
        throwsA(isA<XrplCryptoException>()),
      );
      expect(
        () => XrplSecp256k1.deriveIntermediateKeyPair(Uint8List(40)),
        throwsA(isA<XrplCryptoException>()),
      );
    });
    test('produces a 32-byte private key and 33-byte compressed public key',
        () {
      final rootPublicKey = Uint8List(33)..[0] = 0x02;
      final intermediate = XrplSecp256k1.deriveIntermediateKeyPair(
        rootPublicKey,
      );
      expect(intermediate.compressedPublicKey.length, 33);
    });

    test('is deterministic for the same root public key', () {
      final rootPublicKey = Uint8List(33)..[0] = 0x02;
      final a = XrplSecp256k1.deriveIntermediateKeyPair(rootPublicKey);
      final b = XrplSecp256k1.deriveIntermediateKeyPair(rootPublicKey);
      expect(a.privateKey, b.privateKey);
    });

    test('produces different keys for different root public keys', () {
      final rootA = Uint8List(33)..[0] = 0x02;
      final rootB = Uint8List(33)
        ..[0] = 0x02
        ..[1] = 1;
      final a = XrplSecp256k1.deriveIntermediateKeyPair(rootA);
      final b = XrplSecp256k1.deriveIntermediateKeyPair(rootB);
      expect(a.privateKey, isNot(equals(b.privateKey)));
    });

    test(
        'matches an intermediate key pair independently computed via the '
        'Python "ecdsa" library, chained from the same real root key pair '
        'verified in the deriveRootKeyPair tests', () {
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

      final root = XrplSecp256k1.deriveRootKeyPair(entropy);

      // Root public key double-checked against the same value verified
      // in xrpl_secp256k1_test.dart before deriving from it here.
      expect(
        root.compressedPublicKey,
        _hexToBytes(
          '03db0224bae693168e803fd53d4965b'
          '717a2ea577e561c5d5b568b7ae1fd1e51be',
        ),
      );

      final intermediate = XrplSecp256k1.deriveIntermediateKeyPair(
        root.compressedPublicKey,
      );

      expect(
        _bigIntToBytes(intermediate.privateKey, 32),
        _hexToBytes(
          'ea4cd2eb62fac95c089fdf29aab0dff9'
          '4be675fca0314f5c9ba036d2d0032719',
        ),
      );
      expect(
        intermediate.compressedPublicKey,
        _hexToBytes(
          '025fa6167ff153f4dce7ab6aab0bba8f5'
          '0772ec28ad125e733fb0b0fc799add40c',
        ),
      );
    });
  });
}
