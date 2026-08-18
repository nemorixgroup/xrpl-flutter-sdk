// xrpl_flutter_sdk - Quick Start Examples
//
// This file is the entry point for all SDK examples. Each phase's
// examples live in their own file under example/phaseN/, one file
// per sub-version released within that phase.
//
// Technical decisions behind every example (why a library was chosen,
// how it was verified against official sources) are documented at:
// https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk
//
// Running this example:
// ```sh
// dart run example/xrpl_flutter_sdk_example.dart
// ```
// GitHub:
// https://github.com/nemorixgroup/xrpl-flutter-sdk/blob/main/example/xrpl_flutter_sdk_example.dart
//
// Planned phases:
//   Phase 1 - Cryptographic Fundamentals (seeds, secp256k1, Ed25519) - DONE
//   Phase 2 - Addresses (classic address, X-address, base58 XRPL codec) - DONE
//   Phase 3 - Connection Layer (WebSocket/JSON-RPC, Mainnet/Testnet/Devnet) - CURRENT
//   Phase 4 - Core Transactions (Payment, TrustSet, sign, submit)
//   Phase 5 - DEX & Cross-Currency (OfferCreate, AMM, path finding)
//   Phase 6 - Conditionals & Channels (Escrow, Payment Channels, Checks)
//   Phase 7 - Tokenization (NFTs, MPT, Clawback)
//   Phase 8 - Account Security & Compliance (multi-sign, Tickets, Credentials)

import 'phase1/base58_codec_example.dart';
import 'phase1/ed25519_example.dart';
import 'phase1/entropy_example.dart';
import 'phase1/family_seed_example.dart';
import 'phase1/secp256k1_example.dart';
import 'phase1/wallet_example.dart';
import 'phase2/classic_address_example.dart';
import 'phase2/wallet_address_example.dart';
import 'phase2/x_address_example.dart';
import 'phase3/connection_example.dart';
import 'phase3/queries_example.dart';

Future<void> main() async {
  // Phase 1 - Cryptographic Fundamentals
  // https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-1

  print('--- 0.0.1-dev: Entropy generation ---');
  entropyGenerationExample();

  print('\n--- 0.0.2-dev: Base58 codec ---');
  base58CodecExample();

  print('\n--- 0.0.3-dev: Family seed encoding ---');
  familySeedEncodingExample();

  print('\n--- 0.0.4-dev: secp256k1 key derivation ---');
  secp256k1KeyDerivationExample();

  print('\n--- 0.0.4-dev: Ed25519 key derivation ---');
  await ed25519KeyDerivationExample();

  print('\n--- 0.0.5-dev: XRPL Wallet ---');
  await walletExample();

  // Phase 2 - Addresses
  // https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-2

  print('\n--- 0.1.1-dev: Classic Address ---');
  await classicAddressExample();

  print('\n--- 0.1.2-dev: X-Address ---');
  await xAddressExample();

  print('\n--- 0.1.3-dev: Wallet address integration ---');
  await walletAddressExample();

  // Phase 3 - Connection Layer
  // https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-3
  print('\n--- 0.2.1-dev: Connection lifecycle ---');
  await connectionExample();

  print('\n--- 0.2.2-dev: Requests and queries ---');
  await queriesExample();
}
