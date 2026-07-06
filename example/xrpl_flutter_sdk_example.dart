// xrpl_flutter_sdk - Quick Start Examples
//
// This file is the entry point for all SDK examples.
// Each section corresponds to a phase of development.
//
// Implementation details can be found in:
// https://github.com/nemorixgroup/xrpl-flutter-sdk/tree/main/example/
//
// Running this example:
// ```sh
// dart run example/xrpl_flutter_sdk_example.dart
// ```
//
// Planned phases:
//   Phase 1 - Cryptographic Fundamentals (seeds, secp256k1, Ed25519)
//   Phase 2 - Addresses (classic address, X-address, base58 XRPL codec)
//   Phase 3 - Connection Layer (WebSocket/JSON-RPC, Mainnet/Testnet/Devnet)
//   Phase 4 - Core Transactions (Payment, TrustSet, sign, submit)
//   Phase 5 - DEX & Cross-Currency (OfferCreate, AMM, path finding)
//   Phase 6 - Conditionals & Channels (Escrow, Payment Channels, Checks)
//   Phase 7 - Tokenization (NFTs, MPT, Clawback)
//   Phase 8 - Account Security & Compliance (multi-sign, Tickets, Credentials)

import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

void main() {
  entropyGenerationExample();
}

/// Phase 1 - 0.0.1-dev: Entropy generation.
///
/// Entropy is the random foundation used to build an XRPL seed. The
/// XRP Ledger requires exactly 16 bytes of entropy, regardless of
/// which signing algorithm (secp256k1 or Ed25519) will later be
/// derived from it.
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
