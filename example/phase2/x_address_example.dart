// Phase 2 - 0.1.2-dev: X-Address derivation.
//
// Full technical decisions:
// https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-2/x-address

import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

/// An X-Address packages the account, the network (Mainnet/Testnet),
/// and an optional destination tag into a single address string, so
/// a sender can never "forget" to include the tag separately.
Future<void> xAddressExample() async {
  final wallet = await XrplWallet.generate(
    algorithm: XrplKeyAlgorithm.ed25519,
  );

  final mainnetAddress = XrplXAddress.deriveFrom(
    wallet.publicKeyBytes,
    network: XrplNetwork.mainnet,
    tag: 12345,
  );
  print('Mainnet X-Address (with tag): $mainnetAddress'); // starts with "X"

  final testnetAddress = XrplXAddress.deriveFrom(
    wallet.publicKeyBytes,
    network: XrplNetwork.testnet,
  );
  print('Testnet X-Address (no tag): $testnetAddress'); // starts with "T"

  // An out-of-range tag is rejected explicitly.
  try {
    XrplXAddress.deriveFrom(
      wallet.publicKeyBytes,
      network: XrplNetwork.mainnet,
      tag: -1,
    );
  } on XrplCryptoException catch (e) {
    print('Expected validation error: ${e.message}');
  }
}
