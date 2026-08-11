import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/address/xrpl_network.dart';
import 'package:xrpl_flutter_sdk/src/address/xrpl_x_address.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_key_algorithm.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';
import 'package:xrpl_flutter_sdk/src/wallet/xrpl_wallet.dart';

void main() {
  group('XrplWallet.xAddress', () {
    test('starts with "X" for mainnet', () async {
      final wallet = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.ed25519,
      );
      final address = wallet.xAddress(network: XrplNetwork.mainnet);
      expect(address, startsWith('X'));
    });

    test('starts with "T" for testnet', () async {
      final wallet = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.ed25519,
      );
      final address = wallet.xAddress(network: XrplNetwork.testnet);
      expect(address, startsWith('T'));
    });

    test('matches XrplXAddress.deriveFrom for the same public key', () async {
      final wallet = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.secp256k1,
      );
      expect(
        wallet.xAddress(network: XrplNetwork.mainnet, tag: 42),
        XrplXAddress.deriveFrom(
          wallet.publicKeyBytes,
          network: XrplNetwork.mainnet,
          tag: 42,
        ),
      );
    });

    test('a present tag changes the resulting address versus no tag', () async {
      final wallet = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.ed25519,
      );
      final withoutTag = wallet.xAddress(network: XrplNetwork.mainnet);
      final withTag = wallet.xAddress(network: XrplNetwork.mainnet, tag: 0);
      expect(withoutTag, isNot(equals(withTag)));
    });

    test('propagates the tag range error from XrplXAddress', () async {
      final wallet = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.ed25519,
      );
      expect(
        () => wallet.xAddress(network: XrplNetwork.mainnet, tag: -1),
        throwsA(isA<XrplCryptoException>()),
      );
    });
  });
}
