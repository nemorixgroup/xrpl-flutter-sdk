# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## 0.0.1-dev

Phase 1 in progress: entropy generation implemented and verified
against the official `xrpl-keypairs` specification.

### Added

- `XrplEntropy.generate()`: generates 16 bytes of cryptographically
  secure random entropy using `dart:math`'s `Random.secure`, matching
  the length required by the official `xrpl-keypairs` library
  (Ripple's reference implementation)
- `XrplEntropy.fromBytes(Uint8List)`: restores entropy from previously
  saved bytes, validating length before accepting it
- `XrplEntropy.validate(Uint8List)`: static validation helper, throws
  `XrplCryptoException` on invalid length instead of failing silently
- `XrplCryptoException`: dedicated exception type for cryptographic
  validation errors across the SDK
- 11 unit tests covering length validation, randomness across calls,
  immutability of stored bytes, and error message content
- `example/xrpl_flutter_sdk_example.dart`: working example of
  generating, restoring, and handling invalid entropy

### Changed

- `analysis_options.yaml`: excluded `example/` from strict analysis,
  since `avoid_print` is expected in example code, not library code

### Design Decisions

- Chose `dart:math` over `dart:io` for randomness so the SDK keeps
  the door open for Flutter Web support without rewriting Phase 1 code
- Algorithm (`secp256k1` / `Ed25519`) is a required parameter
  everywhere, never inferred from context, to avoid the same-seed/
  different-address ambiguity documented on xrpl.org

### Status

Phase 1 in progress: entropy generation complete and tested. No
network interaction yet (that begins in Phase 3).  
Not ready for production use.  
Next: base58 XRPL codec (`0.0.2-dev`).
