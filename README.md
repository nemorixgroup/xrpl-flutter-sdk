[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-teal.svg)](https://opensource.org/licenses/Apache-2.0)
[![Dart](https://img.shields.io/badge/Dart-3.x-teal.svg)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![CI](https://github.com/nemorixgroup/xrpl-flutter-sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/nemorixgroup/xrpl-flutter-sdk/actions)
[![Status](https://img.shields.io/badge/Status-Phase%201%20Complete-brightgreen.svg)](https://github.com/nemorixgroup/xrpl-flutter-sdk/blob/main)
[![Status](https://img.shields.io/badge/Status-Phase%202%20In%20Progress-red.svg)](https://github.com/nemorixgroup/xrpl-flutter-sdk/blob/main)  

**English** | [Español](README.es.md)  

# xrpl_flutter_sdk  

The first native Flutter/Dart SDK for the XRP Ledger (XRPL).  
Pure Dart · No platform channels · Apache 2.0 · pub.dev  

> **Status: Early Development** - API is not stable.
> Phase 1 (Cryptographic Fundamentals) completed. Phase 2 (Addresses) starting next.

Built to be an **open, general-purpose XRPL SDK**: payments, DEX,
tokenization (NFTs, MPT), escrows, payment channels, checks, and
account security, all in one native Dart package.

## Roadmap (v1.0.0)

| Phase | Focus | Version | Status |
|-------|-------|---------|--------|
| 1 | Cryptographic fundamentals (seeds, secp256k1, Ed25519) | `0.1.0-dev` | ✅ Done |
| 2 | Addresses (classic address, X-address, base58 XRPL codec) | `0.2.0-dev` | 🔄 In progress |
| 3 | Connection layer (WebSocket/JSON-RPC, Mainnet/Testnet/Devnet) | `0.3.0-dev` | ⏳ Planned |
| 4 | Core transactions (Payment, TrustSet, sign, submit) | `0.4.0-dev` | ⏳ Planned |
| 5 | DEX & cross-currency (OfferCreate, AMM, path finding) | `0.5.0-dev` | ⏳ Planned |
| 6 | Conditionals & channels (Escrow, Payment Channels, Checks) | `0.6.0-dev` | ⏳ Planned |
| 7 | Tokenization (NFTs, MPT, Clawback) | `0.7.0-dev` | ⏳ Planned |
| 8 | Account security & compliance (multi-sign, Tickets, Credentials) | `1.0.0` | ⏳ Planned |

## Documentation & Knowledge Base

This SDK is built on top of the [XRPL Knowledge Base](https://github.com/nemorixgroup/XRPL-Knowledge-Base), an in-depth guide to the XRP Ledger covering consensus,
architecture, native services, and the development ecosystem. Recommended
reading before diving into the SDK internals.

Every implementation decision behind this SDK - library choices,
encoding standards, verification against official specs - is
documented in [docs-sdk/](https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk).

## Installation

```yaml
# pubspec.yaml
dependencies:
  xrpl_flutter_sdk: ^0.1.1-dev
```

```bash
flutter pub get
```

## Quick Start

```dart
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

// Generate a new seed. The algorithm is always explicit - never
// inferred - because the same seed produces a different key pair
// (and a different address) depending on the algorithm used.
final seed = XrplSeed.generate(algorithm: XrplKeyAlgorithm.ed25519);
print(seed.toBase58()); // e.g. "sEdT..."

// Restore a seed from a saved string. The checksum is verified
// automatically; a mistyped or corrupted seed throws
// XrplCryptoException instead of silently producing wrong data.
final restored = XrplSeed.fromBase58(seed.toBase58());
print(restored.declaredAlgorithm); // XrplKeyAlgorithm.ed25519
```

```dart
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

// secp256k1: synchronous key derivation.
final secpSeed = XrplSeed.generate(algorithm: XrplKeyAlgorithm.secp256k1);
final secpKeys = XrplSecp256k1.deriveKeyPair(secpSeed.entropy);
print(secpKeys.compressedPublicKey); // 33 bytes

// Ed25519: asynchronous key derivation (see docs-sdk/ for why).
final edSeed = XrplSeed.generate(algorithm: XrplKeyAlgorithm.ed25519);
final edKeys = await XrplEd25519.deriveKeyPair(edSeed.entropy);
print(edKeys.prefixedPublicKey); // 33 bytes, 0xED-prefixed
```

```dart
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

// Classic address: derived from a public key, reusing the same
// checksummed base58 encoding already used for seeds.
final wallet = await XrplWallet.generate(algorithm: XrplKeyAlgorithm.ed25519);
final address = XrplClassicAddress.deriveFrom(wallet.publicKeyBytes);
print(address); // "r..."
```

> Address generation and network connectivity are coming in the next
> releases. See the Roadmap table above for current status.

## Networks

| Network | WebSocket URL |
|---------|----------------|
| Mainnet | `wss://xrplcluster.com` |
| Testnet | `wss://s.altnet.rippletest.net:51233` |
| Devnet  | `wss://s.devnet.rippletest.net:51233` |

## Contributing

The SDK is not ready for external contributions yet.
Follow this repository for updates; contributions will
be welcome starting with v1.0.0.

See [CONTRIBUTING.md](CONTRIBUTING.md) for future guidelines.

## License

Licensed under [Apache 2.0](LICENSE).

## For LATAM developers

This SDK is being developed with native support for the region in mind:

- Bilingual documentation (English / Spanish) from the very first module.
- Part of Nemorix Group's SDK ecosystem for financial infrastructure
  in LATAM (Hedera, Avalanche, XRPL).
- Developed by [Nemorix Group](https://nemorixpay.com), Ohio, USA.

Follow us for updates: **sdks@nemorixpay.com**

## Support This Project

If this SDK is useful to you or your team, consider supporting its
development. Every contribution helps cover infrastructure,
documentation, and the time invested in building and maintaining this
open source tool for the XRPL and Flutter community. Thank you!

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Support-FFDD00?logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/nemorixgroupllc)
[![Sponsor](https://img.shields.io/badge/Sponsor-GitHub-EA4AAA?logo=github-sponsors&logoColor=white)](https://github.com/sponsors/nemorixgroup)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Support-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/nemorixgroupllc)

---

Built by [Nemorix Group](https://nemorixpay.com) · Apache 2.0
