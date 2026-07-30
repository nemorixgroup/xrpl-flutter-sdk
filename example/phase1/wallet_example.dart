// Phase 1 - 0.0.5-dev: XrplWallet, the unified public API.
//
// Full technical decisions: https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-1/wallet

import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

/// XrplWallet unifies seed generation and key derivation behind one
/// consistently async API, regardless of algorithm - hiding that
/// secp256k1 derivation is actually synchronous internally while
/// Ed25519 genuinely isn't.
Future<void> walletExample() async {
  final wallet = await XrplWallet.generate(
    algorithm: XrplKeyAlgorithm.ed25519,
  );
  print('Seed: ${wallet.seed.toBase58()}');
  print('Public key (${wallet.publicKeyBytes.length} bytes): '
      '${wallet.publicKeyBytes}');

  final restored = await XrplWallet.fromSeed(
    wallet.seed.toBase58(),
    algorithm: XrplKeyAlgorithm.ed25519,
  );
  print('Restored matches: '
      '${restored.privateKeyBytes.toString() == wallet.privateKeyBytes.toString()}');

  // An sEd-declared seed used with the wrong algorithm is rejected,
  // never silently derived incorrectly.
  try {
    await XrplWallet.fromSeed(
      wallet.seed.toBase58(),
      algorithm: XrplKeyAlgorithm.secp256k1,
    );
  } on XrplCryptoException catch (e) {
    print('Expected validation error: ${e.message}');
  }
}
