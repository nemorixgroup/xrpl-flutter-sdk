# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## 0.0.2-dev

Phase 1 in progress: XRPL base58 codec implemented and verified,
including checksum-based corruption detection.

### Added

- `XrplBase58.encodeRaw(Uint8List)`: encodes raw bytes into an XRPL
  base58 string using the ledger's own alphabet (distinct from
  Bitcoin's), preserving leading zero bytes correctly
- `XrplBase58.decodeRaw(String)`: exact inverse of `encodeRaw`,
  rejects any character outside the XRPL alphabet
- `XrplBase58.checksumOf(Uint8List)`: computes the 4-byte
  double-SHA256 checksum (`Base58Check` style) used by XRPL seeds
  and addresses, via `pointycastle`'s `SHA256Digest`
- `XrplBase58.encodeWithChecksum(Uint8List)`: encodes data with the
  checksum appended
- `XrplBase58.decodeWithChecksum(String)`: decodes and verifies the
  embedded checksum, throwing `XrplCryptoException` on a mismatch,
  on invalid characters, or on data too short to contain a checksum
- 43 unit tests total (up from 10), including:
  - round-trip tests between `encodeRaw`/`decodeRaw` across multiple
    byte patterns (including leading zeros)
  - a checksum test vector computed independently via Python's
    `hashlib`, not just structural assertions
  - a real mistyped-character scenario proving `decodeWithChecksum`
    catches corrupted input instead of silently returning bad data

### Changed

- `lib/xrpl_flutter_sdk.dart`: exported `XrplBase58` now that its
  public API (encode/decode, with and without checksum) is complete

### Design Decisions

- Split raw conversion (`encodeRaw`/`decodeRaw`) from checksummed
  conversion (`encodeWithChecksum`/`decodeWithChecksum`) instead of
  a single function, since not everything encoded in XRPL base58
  carries a checksum, and the checksummed versions are built on top
  of the raw ones rather than duplicating the conversion logic
- `decodeWithChecksum` verifies the checksum unconditionally; there
  is no "skip verification" option, to prevent silently accepting
  corrupted seeds or addresses

### Status

Phase 1 in progress: entropy generation and base58 codec complete
and tested. No network interaction yet (that begins in Phase 3).  
Not ready for production use.  
Next: family seed encoding (`0.0.3-dev`), combining `XrplEntropy` and
`XrplBase58`.

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
