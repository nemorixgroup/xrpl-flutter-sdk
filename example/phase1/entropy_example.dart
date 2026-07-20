/// Phase 1 - 0.0.1-dev: Entropy generation.
///
/// Entropy is the random foundation used to build an XRPL seed. The
/// XRP Ledger requires exactly 16 bytes of entropy, regardless of
/// which signing algorithm (secp256k1 or Ed25519) will later be
/// derived from it.
///
/// // Full technical decisions:
/// https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-1/entropy
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

void entropyGenerationExample() {
  // Generate fresh, cryptographically secure entropy.
  final entropy = XrplEntropy.generate();
  print('Generated entropy (${entropy.bytes.length} bytes): '
      '${entropy.bytes}');

  // Restoring entropy from previously saved bytes works the same way,
  // and validates the length automatically.
  final restored = XrplEntropy.fromBytes(entropy.bytes);
  print('Restored entropy matches original: '
      '${_bytesEqual(entropy.bytes, restored.bytes)}');

  // Invalid entropy is rejected with a clear error, never silently
  // accepted.
  try {
    XrplEntropy.fromBytes(entropy.bytes.sublist(0, 8));
  } on XrplCryptoException catch (e) {
    print('Expected validation error: ${e.message}');
  }
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
