/// Phase 1 - 0.0.3-dev: Family seed encoding.
///
/// A family seed is the human-shareable string a user saves to
/// recreate their key pair and address later. It combines entropy
/// with a prefix that identifies it as an XRPL seed, plus a checksum
/// to catch typos or corruption.
///
/// Full technical decisions:
/// https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-1/family-seed-encoding
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

void familySeedEncodingExample() {
  // The algorithm is always explicit when generating a seed - never
  // inferred - because the same entropy produces a different key
  // pair (and address) depending on the algorithm used later.
  final ed25519Seed = XrplSeed.generate(algorithm: XrplKeyAlgorithm.ed25519);
  print('Ed25519 seed: ${ed25519Seed.toBase58()}'); // starts with "sEd"

  final secp256k1Seed = XrplSeed.generate(
    algorithm: XrplKeyAlgorithm.secp256k1,
  );
  print('secp256k1 seed: ${secp256k1Seed.toBase58()}'); // starts with "s"

  // Restoring a seed verifies its checksum automatically.
  final restored = XrplSeed.fromBase58(ed25519Seed.toBase58());
  print('Restored seed declares algorithm: ${restored.declaredAlgorithm}');

  // A mistyped or corrupted seed is rejected explicitly, never
  // silently accepted as valid.
  try {
    XrplSeed.fromBase58('sEdCorruptedSeedExample1234567');
  } on XrplCryptoException catch (e) {
    print('Expected validation error: ${e.message}');
  }
}
