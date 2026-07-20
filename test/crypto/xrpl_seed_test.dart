import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/codec/xrpl_base58.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_entropy.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_key_algorithm.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_seed.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return result;
}

void main() {
  group('XrplSeed.generate', () {
    test('secp256k1 seeds do not declare an algorithm (generic prefix)', () {
      final seed = XrplSeed.generate(algorithm: XrplKeyAlgorithm.secp256k1);
      expect(seed.declaredAlgorithm, isNull);
    });

    test('ed25519 seeds declare ed25519 (sEd prefix)', () {
      final seed = XrplSeed.generate(algorithm: XrplKeyAlgorithm.ed25519);
      expect(seed.declaredAlgorithm, XrplKeyAlgorithm.ed25519);
    });

    test('ed25519 seeds encode to a string starting with "sEd"', () {
      final seed = XrplSeed.generate(algorithm: XrplKeyAlgorithm.ed25519);
      expect(seed.toBase58(), startsWith('sEd'));
    });

    test('secp256k1 seeds encode to a string starting with "s" (not sEd)', () {
      final seed = XrplSeed.generate(algorithm: XrplKeyAlgorithm.secp256k1);
      expect(seed.toBase58(), startsWith('s'));
      expect(seed.toBase58(), isNot(startsWith('sEd')));
    });

    test('produces different seeds on each call', () {
      final a = XrplSeed.generate(algorithm: XrplKeyAlgorithm.secp256k1);
      final b = XrplSeed.generate(algorithm: XrplKeyAlgorithm.secp256k1);
      expect(a.toBase58(), isNot(equals(b.toBase58())));
    });
  });

  group('XrplSeed round-trip (generate -> toBase58 -> fromBase58)', () {
    test('recovers the same entropy and declared algorithm (secp256k1)', () {
      final original = XrplSeed.generate(
        algorithm: XrplKeyAlgorithm.secp256k1,
      );
      final restored = XrplSeed.fromBase58(original.toBase58());
      expect(restored.entropy.bytes, original.entropy.bytes);
      expect(restored.declaredAlgorithm, isNull);
    });

    test('recovers the same entropy and declared algorithm (ed25519)', () {
      final original = XrplSeed.generate(algorithm: XrplKeyAlgorithm.ed25519);
      final restored = XrplSeed.fromBase58(original.toBase58());
      expect(restored.entropy.bytes, original.entropy.bytes);
      expect(restored.declaredAlgorithm, XrplKeyAlgorithm.ed25519);
    });
  });

  group('XrplSeed against official ripple-address-codec test vectors', () {
    // These four vectors are taken directly from the official
    // ripple-address-codec test suite (xrp-codec.test.ts), not
    // computed by us, and were re-verified independently via a
    // standalone Python re-implementation before use here.

    test('Ed25519 vector 1: mid-range entropy', () {
      final entropy = _hexToBytes('4C3A1D213FBDFB14C7C28D609469B341');
      final seed = XrplSeed(
        XrplEntropy.fromBytes(entropy),
        declaredAlgorithm: XrplKeyAlgorithm.ed25519,
      );
      expect(seed.toBase58(), 'sEdTM1uX8pu2do5XvTnutH6HsouMaM2');
    });

    test('Ed25519 vector 2: all-zero entropy', () {
      final entropy = Uint8List(16);
      final seed = XrplSeed(
        XrplEntropy.fromBytes(entropy),
        declaredAlgorithm: XrplKeyAlgorithm.ed25519,
      );
      expect(seed.toBase58(), 'sEdSJHS4oiAdz7w2X2ni1gFiqtbJHqE');
    });

    test('Ed25519 vector 3: all-0xFF entropy', () {
      final entropy = Uint8List.fromList(List.filled(16, 0xFF));
      final seed = XrplSeed(
        XrplEntropy.fromBytes(entropy),
        declaredAlgorithm: XrplKeyAlgorithm.ed25519,
      );
      expect(seed.toBase58(), 'sEdV19BLfeQeKdEXyYA4NhjPJe6XBfG');
    });

    test('secp256k1 vector: decodes a known seed to its known entropy', () {
      const knownSeed = 'sn259rEFXrQrWyx3Q7XneWcwV6dfL';
      final seed = XrplSeed.fromBase58(knownSeed);
      expect(seed.declaredAlgorithm, isNull);
      expect(
        seed.entropy.bytes,
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
    });

    test('secp256k1 vector: re-encodes back to the exact original string', () {
      const knownSeed = 'sn259rEFXrQrWyx3Q7XneWcwV6dfL';
      expect(XrplSeed.fromBase58(knownSeed).toBase58(), knownSeed);
    });
  });

  group('XrplSeed.fromBase58 error handling', () {
    test('throws on a checksum mismatch', () {
      // Known-good Ed25519 vector with the last character altered.
      const corrupted = 'sEdSJHS4oiAdz7w2X2ni1gFiqtbJHqF';
      expect(
        () => XrplSeed.fromBase58(corrupted),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('throws on a decodable but unrecognized prefix/length', () {
      // Valid base58Check string, but not 17 or 19 raw bytes, so no
      // known XRPL seed prefix can match it.
      final bogus = XrplEntropy.generate().bytes; // 16 raw bytes, no prefix
      final encoded = XrplBase58.encodeWithChecksum(bogus);
      expect(
        () => XrplSeed.fromBase58(encoded),
        throwsA(isA<XrplCryptoException>()),
      );
    });
  });
}
