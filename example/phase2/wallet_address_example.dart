// Phase 2 - 0.1.3-dev: address integration into XrplWallet.
//
// Full technical decisions:
// https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-2/wallet-address-integration

import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

/// XrplWallet now exposes its address directly, so callers don't
/// need to call XrplClassicAddress or XrplXAddress separately.
Future<void> walletAddressExample() async {
  final wallet = await XrplWallet.generate(
    algorithm: XrplKeyAlgorithm.ed25519,
  );

  // classicAddress is a field: already computed, no parameters needed.
  print('Classic address: ${wallet.classicAddress}');

  // xAddress is a method: needs the network, and optionally a tag.
  final mainnetAddress = wallet.xAddress(
    network: XrplNetwork.mainnet,
    tag: 12345,
  );
  print('Mainnet X-Address: $mainnetAddress');

  final testnetAddress = wallet.xAddress(network: XrplNetwork.testnet);
  print('Testnet X-Address (no tag): $testnetAddress');
}
