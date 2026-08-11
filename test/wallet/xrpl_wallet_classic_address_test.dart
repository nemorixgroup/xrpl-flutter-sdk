import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/address/xrpl_classic_address.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_key_algorithm.dart';
import 'package:xrpl_flutter_sdk/src/wallet/xrpl_wallet.dart';

void main() {
  group('XrplWallet.classicAddress', () {
    test('is present and starts with "r" for secp256k1 wallets', () async {
      final wallet = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.secp256k1,
      );
      expect(wallet.classicAddress, startsWith('r'));
    });

    test('is present and starts with "r" for ed25519 wallets', () async {
      final wallet = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.ed25519,
      );
      expect(wallet.classicAddress, startsWith('r'));
    });

    test('matches XrplClassicAddress.deriveFrom for the same public key',
        () async {
      final wallet = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.ed25519,
      );
      expect(
        wallet.classicAddress,
        XrplClassicAddress.deriveFrom(wallet.publicKeyBytes),
      );
    });

    test('is deterministic when restoring the same wallet from its seed',
        () async {
      final original = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.secp256k1,
      );
      final restored = await XrplWallet.fromSeed(
        original.seed.toBase58(),
        algorithm: XrplKeyAlgorithm.secp256k1,
      );
      expect(restored.classicAddress, original.classicAddress);
    });
  });
}
