// Phase 2 - 0.1.1-dev: Classic Address derivation.
//
// Full technical decisions: https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-2/classic-address

import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

/// A classic address ("r...") is derived from a public key via
/// RIPEMD160(SHA256(publicKey)), then base58-encoded with a checksum -
/// the same XrplBase58.encodeWithChecksum already used for seeds.
Future<void> classicAddressExample() async {
  final wallet = await XrplWallet.generate(
    algorithm: XrplKeyAlgorithm.ed25519,
  );

  final address = XrplClassicAddress.deriveFrom(wallet.publicKeyBytes);
  print('Classic address: $address'); // starts with "r"

  // Deterministic: the same public key always derives the same address.
  final again = XrplClassicAddress.deriveFrom(wallet.publicKeyBytes);
  print('Deterministic: ${address == again}');

  // Invalid public key length is rejected explicitly.
  try {
    XrplClassicAddress.deriveFrom(wallet.publicKeyBytes.sublist(0, 10));
  } on XrplCryptoException catch (e) {
    print('Expected validation error: ${e.message}');
  }
}
