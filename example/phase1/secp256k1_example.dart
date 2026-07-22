// Phase 1 - 0.0.4-dev: secp256k1 key derivation.
//
// Full technical decisions: https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-1/key-derivation

import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

/// secp256k1 is XRPL's original, default signing algorithm. Deriving
/// a key pair combines a "root" and an "intermediate" key pair, a
/// leftover part of an unfinished "key family" design that XRPL still
/// requires today.
void secp256k1KeyDerivationExample() {
  final seed = XrplSeed.generate(algorithm: XrplKeyAlgorithm.secp256k1);
  final keyPair = XrplSecp256k1.deriveKeyPair(seed.entropy);

  print('secp256k1 seed: ${seed.toBase58()}');
  print(
    'secp256k1 compressed public key '
    '(${keyPair.compressedPublicKey.length} bytes): '
    '${keyPair.compressedPublicKey}',
  );

  // Deterministic: the same seed always derives the same key pair.
  final again = XrplSecp256k1.deriveKeyPair(seed.entropy);
  print(
    'Deterministic: '
    '${keyPair.compressedPublicKey.toString() == again.compressedPublicKey.toString()}',
  );
}
