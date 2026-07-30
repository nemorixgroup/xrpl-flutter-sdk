import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_key_algorithm.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';
import 'package:xrpl_flutter_sdk/src/wallet/xrpl_wallet.dart';

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return result;
}

void main() {
  group('XrplWallet.generate', () {
    test('secp256k1: produces 32-byte private key and 33-byte public key',
        () async {
      final wallet = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.secp256k1,
      );
      expect(wallet.privateKeyBytes.length, 32);
      expect(wallet.publicKeyBytes.length, 33);
      expect(wallet.algorithm, XrplKeyAlgorithm.secp256k1);
    });

    test('ed25519: produces 32-byte private key and 33-byte public key',
        () async {
      final wallet = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.ed25519,
      );
      expect(wallet.privateKeyBytes.length, 32);
      expect(wallet.publicKeyBytes.length, 33);
      expect(wallet.publicKeyBytes[0], 0xED);
      expect(wallet.algorithm, XrplKeyAlgorithm.ed25519);
    });

    test('produces different wallets on each call', () async {
      final a = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.secp256k1,
      );
      final b = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.secp256k1,
      );
      expect(a.privateKeyBytes, isNot(equals(b.privateKeyBytes)));
    });
  });

  group('XrplWallet.fromSeed round-trip', () {
    test('secp256k1: restores the same wallet from its own seed', () async {
      final original = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.secp256k1,
      );
      final restored = await XrplWallet.fromSeed(
        original.seed.toBase58(),
        algorithm: XrplKeyAlgorithm.secp256k1,
      );
      expect(restored.privateKeyBytes, original.privateKeyBytes);
      expect(restored.publicKeyBytes, original.publicKeyBytes);
    });

    test('ed25519: restores the same wallet from its own seed', () async {
      final original = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.ed25519,
      );
      final restored = await XrplWallet.fromSeed(
        original.seed.toBase58(),
        algorithm: XrplKeyAlgorithm.ed25519,
      );
      expect(restored.privateKeyBytes, original.privateKeyBytes);
      expect(restored.publicKeyBytes, original.publicKeyBytes);
    });
  });

  group('XrplWallet.fromSeed algorithm mismatch protection', () {
    test(
        'throws when an sEd-declared (ed25519) seed is used with '
        'secp256k1', () async {
      final ed25519Wallet = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.ed25519,
      );
      final seedString = ed25519Wallet.seed.toBase58();

      expect(
        () => XrplWallet.fromSeed(
          seedString,
          algorithm: XrplKeyAlgorithm.secp256k1,
        ),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test(
        'does not throw when a generic (non-declared) seed is used with '
        'either algorithm', () async {
      final genericWallet = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.secp256k1,
      );
      final seedString = genericWallet.seed.toBase58();

      // A generic seed makes no declaration, so requesting either
      // algorithm with it is valid - this is expected, not a bug.
      await expectLater(
        XrplWallet.fromSeed(seedString, algorithm: XrplKeyAlgorithm.ed25519),
        completes,
      );
    });
  });

  group('XrplWallet against previously verified real vectors', () {
    test(
        'secp256k1: matches the master key pair already verified in '
        'xrpl_secp256k1_master_test.dart, chained from the real seed '
        'sn259rEFXrQrWyx3Q7XneWcwV6dfL', () async {
      final wallet = await XrplWallet.fromSeed(
        'sn259rEFXrQrWyx3Q7XneWcwV6dfL',
        algorithm: XrplKeyAlgorithm.secp256k1,
      );

      expect(
        wallet.privateKeyBytes,
        _hexToBytes(
          '48d93a3b5948e5f9b323bf654bfad6e8'
          'ff75b5fcab03c5a55ad30cb2515b461f',
        ),
      );
      expect(
        wallet.publicKeyBytes,
        _hexToBytes(
          '0203f2d90bc50012ec7cb20b07a1b818d6'
          '863636fb1e945d17449092cfb5495e1e',
        ),
      );
    });

    test(
        'ed25519: matches the key pair already verified in '
        'xrpl_ed25519_test.dart, chained from the real seed '
        'sEdTM1uX8pu2do5XvTnutH6HsouMaM2', () async {
      final wallet = await XrplWallet.fromSeed(
        'sEdTM1uX8pu2do5XvTnutH6HsouMaM2',
        algorithm: XrplKeyAlgorithm.ed25519,
      );

      expect(
        wallet.privateKeyBytes,
        _hexToBytes(
          '0bf5f1f124c884b1a5ae4a48c816fcf5'
          '54fc3a0d9a07c0f7eb1ca91f7b94814c',
        ),
      );
      expect(
        wallet.publicKeyBytes,
        _hexToBytes(
          'eda57ebbcb502c2009efe17229e8dc86'
          '5dccb192c52d7888d624dc9ebaddb815f0',
        ),
      );
    });
  });
}
