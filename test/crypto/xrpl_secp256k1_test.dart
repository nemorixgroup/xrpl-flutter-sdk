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

void main() {
  group('XrplSecp256k1.deriveRootKeyPair', () {
    test('produces a 32-byte private key and 33-byte compressed public key',
        () {
      final entropy = XrplEntropy.fromBytes(Uint8List(16));
      final keyPair = XrplSecp256k1.deriveRootKeyPair(entropy);
      expect(keyPair.compressedPublicKey.length, 33);
    });

    test('is deterministic for the same entropy', () {
      final entropy = XrplEntropy.fromBytes(
        Uint8List.fromList(List.generate(16, (i) => i)),
      );
      final a = XrplSecp256k1.deriveRootKeyPair(entropy);
      final b = XrplSecp256k1.deriveRootKeyPair(entropy);
      expect(a.privateKey, b.privateKey);
      expect(a.compressedPublicKey, b.compressedPublicKey);
    });

    test('produces different keys for different entropy', () {
      final a = XrplSecp256k1.deriveRootKeyPair(
        XrplEntropy.fromBytes(Uint8List(16)),
      );
      final b = XrplSecp256k1.deriveRootKeyPair(
        XrplEntropy.fromBytes(
          Uint8List.fromList(List.filled(16, 1)),
        ),
      );
      expect(a.privateKey, isNot(equals(b.privateKey)));
    });

    test(
        'matches a root key pair independently computed via the Python '
        '"ecdsa" library, using the known secp256k1 seed entropy from '
        'sn259rEFXrQrWyx3Q7XneWcwV6dfL (see xrpl_seed_test.dart)', () {
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

      final keyPair = XrplSecp256k1.deriveRootKeyPair(entropy);

      expect(
        _bigIntToBytes(keyPair.privateKey, 32),
        _hexToBytes(
          '5e8c674ff64e1c9daa83e03ba149f6ee'
          '6e3e1ce6ba1b16847f05346c518e6047',
        ),
      );
      expect(
        keyPair.compressedPublicKey,
        _hexToBytes(
          '03db0224bae693168e803fd53d4965b'
          '717a2ea577e561c5d5b568b7ae1fd1e51be',
        ),
      );
    });
  });
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
