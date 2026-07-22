// Phase 1 - 0.0.4-dev: Ed25519 key derivation.
//
// Full technical decisions: https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-1/key-derivation

import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

/// Ed25519 is simpler than secp256k1: a single hash produces the
/// secret key directly, with no root/intermediate split or validity
/// retry loop. Derivation is asynchronous here because it relies on
/// package:cryptography (actively maintained), unlike secp256k1's
/// synchronous pointycastle-based derivation.
Future<void> ed25519KeyDerivationExample() async {
  final seed = XrplSeed.generate(algorithm: XrplKeyAlgorithm.ed25519);
  final keyPair = await XrplEd25519.deriveKeyPair(seed.entropy);

  print('Ed25519 seed: ${seed.toBase58()}'); // starts with "sEd"
  print(
    'Ed25519 public key with 0xED prefix '
    '(${keyPair.prefixedPublicKey.length} bytes): '
    '${keyPair.prefixedPublicKey}',
  );
}
