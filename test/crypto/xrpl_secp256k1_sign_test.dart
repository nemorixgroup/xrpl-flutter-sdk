import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_secp256k1.dart';

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return result;
}

void main() {
  group('XrplSecp256k1.sign', () {
    // Reuses the same secp256k1 master key pair already verified in
    // xrpl_secp256k1_master_test.dart (Phase 1) - both the private
    // key (to sign) and its exact public key point (to verify
    // against), so this test is self-contained and does not depend
    // on any external signature value that another library's RFC
    // 6979 nonce derivation might compute differently (this SDK's
    // signature is deterministic and canonical, but not guaranteed
    // to be byte-identical to a different independent implementation
    // signing the same message - both can be, and are, independently
    // valid).
    final privateKey = BigInt.parse(
      '48d93a3b5948e5f9b323bf654bfad6e8ff75b5fcab03c5a55ad30cb2515b461f',
      radix: 16,
    );
    final publicKeyCompressed = _hexToBytes(
      '0203f2d90bc50012ec7cb20b07a1b818d6863636fb1e945d17449092cfb5495e1e',
    );
    final messageHash = _hexToBytes(
      '6dd9b74a2a531cdb5df8ad1eb1c2bc4ede95a1e6613f28d646966ce5daa3f565',
    );

    test(
        'produces a signature that verifies against the correct public '
        'key', () {
      final signature = XrplSecp256k1.sign(messageHash, privateKey);
      final publicKeyPoint =
          XrplSecp256k1.decodeCompressedPublicKey(publicKeyCompressed);

      final isValid = XrplSecp256k1.verify(
        messageHash,
        signature,
        publicKeyPoint,
      );
      expect(isValid, isTrue);
    });

    test('a signature does not verify against a different message hash', () {
      final signature = XrplSecp256k1.sign(messageHash, privateKey);
      final publicKeyPoint =
          XrplSecp256k1.decodeCompressedPublicKey(publicKeyCompressed);

      // Exactly 32 zero bytes, built programmatically instead of hand-typed
      final differentHash = Uint8List(32);

      final isValid = XrplSecp256k1.verify(
        differentHash,
        signature,
        publicKeyPoint,
      );
      expect(isValid, isFalse);
    });

    test(
        'is deterministic: signing the same hash twice yields the same '
        'signature', () {
      final first = XrplSecp256k1.sign(messageHash, privateKey);
      final second = XrplSecp256k1.sign(messageHash, privateKey);
      expect(first, second);
    });

    test(
        'produces a properly DER-encoded signature (starts with the '
        'SEQUENCE tag)', () {
      final signature = XrplSecp256k1.sign(messageHash, privateKey);
      expect(signature[0], 0x30); // DER SEQUENCE tag
    });

    test('produces a signature with S in the canonical (low-S) range', () {
      final signature = XrplSecp256k1.sign(messageHash, privateKey);
      final rLength = signature[3];
      final sLengthIndex = 4 + rLength + 1;
      final sLength = signature[sLengthIndex];
      final sStart = sLengthIndex + 1;
      final sBytes = signature.sublist(sStart, sStart + sLength);
      var s = BigInt.zero;
      for (final byte in sBytes) {
        s = (s << 8) | BigInt.from(byte);
      }
      final order = BigInt.parse(
        'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
        radix: 16,
      );
      expect(s <= order >> 1, isTrue);
    });
  });
}
