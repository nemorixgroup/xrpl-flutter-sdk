import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_ed25519.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_entropy.dart';

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return result;
}

void main() {
  group('XrplEd25519.deriveKeyPair', () {
    test('produces a 32-byte private key and 33-byte prefixed public key',
        () async {
      final entropy = XrplEntropy.fromBytes(Uint8List(16));
      final keyPair = await XrplEd25519.deriveKeyPair(entropy);
      expect(keyPair.privateKey.length, 32);
      expect(keyPair.publicKey.length, 32);
      expect(keyPair.prefixedPublicKey.length, 33);
    });

    test('prefixes the public key with 0xED', () async {
      final entropy = XrplEntropy.fromBytes(Uint8List(16));
      final keyPair = await XrplEd25519.deriveKeyPair(entropy);
      expect(keyPair.prefixedPublicKey[0], 0xED);
      expect(
        keyPair.prefixedPublicKey.sublist(1),
        keyPair.publicKey,
      );
    });

    test('is deterministic for the same entropy', () async {
      final entropy = XrplEntropy.fromBytes(
        Uint8List.fromList(List.generate(16, (i) => i)),
      );
      final a = await XrplEd25519.deriveKeyPair(entropy);
      final b = await XrplEd25519.deriveKeyPair(entropy);
      expect(a.privateKey, b.privateKey);
      expect(a.publicKey, b.publicKey);
    });

    test('produces different keys for different entropy', () async {
      final a = await XrplEd25519.deriveKeyPair(
        XrplEntropy.fromBytes(Uint8List(16)),
      );
      final b = await XrplEd25519.deriveKeyPair(
        XrplEntropy.fromBytes(Uint8List.fromList(List.filled(16, 1))),
      );
      expect(a.privateKey, isNot(equals(b.privateKey)));
    });

    test(
        "matches a key pair independently computed via Python's pynacl "
        '(libsodium), using the known Ed25519 seed entropy from the '
        'official ripple-address-codec test suite '
        '(entropy for sEdTM1uX8pu2do5XvTnutH6HsouMaM2, already verified '
        'in xrpl_seed_test.dart)', () async {
      final entropy = XrplEntropy.fromBytes(
        _hexToBytes('4C3A1D213FBDFB14C7C28D609469B341'.toLowerCase()),
      );

      final keyPair = await XrplEd25519.deriveKeyPair(entropy);

      expect(
        keyPair.privateKey,
        _hexToBytes(
          '0bf5f1f124c884b1a5ae4a48c816fcf5'
          '54fc3a0d9a07c0f7eb1ca91f7b94814c',
        ),
      );
      expect(
        keyPair.publicKey,
        _hexToBytes(
          'a57ebbcb502c2009efe17229e8dc865d'
          'ccb192c52d7888d624dc9ebaddb815f0',
        ),
      );
      expect(
        keyPair.prefixedPublicKey,
        _hexToBytes(
          'eda57ebbcb502c2009efe17229e8dc86'
          '5dccb192c52d7888d624dc9ebaddb815f0',
        ),
      );
    });
  });
}
