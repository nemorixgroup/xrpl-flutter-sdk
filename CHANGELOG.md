# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.3-dev

Phase 2 in progress: address derivation integrated directly into
XrplWallet, so a wallet's address is available without a separate
call to XrplClassicAddress or XrplXAddress.

### Added

- `XrplWallet.classicAddress`: derived once at wallet construction
  and cached as a field, since it never changes for a given wallet
- `XrplWallet.xAddress({required network, tag})`: a method, not a
  cached field, since an X-address depends on parameters that can
  differ on every call
- 9 new unit tests (113 -> 122), covering both new members for both
  algorithms, and confirming they match calling
  `XrplClassicAddress`/`XrplXAddress` directly

### Design Decisions

- `classicAddress` is a field (computed once, immutable); `xAddress`
  is a method (computed per call) - the difference follows directly
  from whether the value depends on call-time parameters
- `XrplClassicAddress` and `XrplXAddress` were not modified; this
  sub-version only wires existing, already-verified pieces together

### Status

Phase 2 in progress: classic address, X-address, and their
integration into XrplWallet complete and tested. No network
interaction yet (that begins in Phase 3).  
Not ready for production use.  
Next: Phase 2 closing audit (error handling review + test
consolidation), closing at `0.2.0-dev`.

## 0.1.2-dev

Phase 2 in progress: X-Address, encoding account, network, and an
optional destination tag into a single address string.

### Added

- `XrplNetwork`: enum for Mainnet/Testnet, used to select the correct
  X-Address prefix
- `XrplXAddress.deriveFrom(publicKey, {required network, tag})`:
  derives an X-Address ("X..." mainnet, "T..." testnet), reusing
  `XrplClassicAddress.accountIdFromPublicKey` and
  `XrplBase58.encodeWithChecksum`
- Tag validation: rejects negative tags or tags above the 32-bit
  maximum (`4294967295`) with `XrplCryptoException`
- 11 new unit tests (102 -> 113), including 2 official test vectors
  (mainnet with the maximum tag, testnet with a small tag) from the
  original `ripple-address-codec` X-Address PR, independently
  re-verified via Python before use

### Fixed

- A test-vector transcription error (reusing the wrong public key
  from an unrelated official example) was caught by an unexpected
  test failure, not by manual review - corrected by re-verifying
  every vector independently in Python before finalizing the test
  file, per this SDK's standing verification practice

### Design Decisions

- Discovered during research that the X-Address payload is 31 bytes
  (2-byte network prefix + 20-byte Account ID + 1-byte flag + 4-byte
  tag + 4 reserved bytes), not 30 as initially assumed - confirmed
  against the official `ripple-address-codec` X-Address PR before
  implementing
- The destination tag is encoded little-endian, the only place in
  this SDK where byte order is reversed from the big-endian
  convention used everywhere else (seeds, keys)
- `tag` is an optional parameter (`int?`), not a required one like
  the signing algorithm elsewhere in the SDK - omitting a tag is a
  valid, common state, unlike omitting the algorithm

### Status

Phase 2 in progress: classic address and X-Address derivation
complete and tested against official vectors. No network interaction
yet (that begins in Phase 3).  
Not ready for production use.  
Next: integrating addresses into `XrplWallet` (`0.1.3-dev`).

## 0.1.1-dev

Phase 2 in progress: classic address derivation from a public key.

### Added

- `XrplClassicAddress.accountIdFromPublicKey(publicKey)`: derives the
  20-byte Account ID via `RIPEMD160(SHA256(publicKey))`
- `XrplClassicAddress.deriveFrom(publicKey)`: derives the full classic
  address (`"r..."`), reusing `XrplBase58.encodeWithChecksum`
- 9 new unit tests (93 -> 102), including the complete official
  worked example published directly in `xrpl-dev-portal`
  (`addresses.md`), independently re-verified via Python before use

### Design Decisions

- New `lib/src/address/` folder, sibling to `crypto/`, `codec/`,
  `wallet/`, `exceptions/` - address derivation is its own concept
  (all of Phase 2), not a cryptographic primitive, and will integrate
  with `XrplWallet` in a later sub-version
- Reuses `XrplBase58.encodeWithChecksum` rather than duplicating the
  checksum/encoding logic - addresses and seeds share the same
  Base58Check-style scheme, just a different type prefix (`0x00` vs
  `0x21`/`0x01 0xE1 0x4B`)

### Status

Phase 2 in progress: classic address derivation complete and tested
against an official worked example.  
Next: X-Address (`0.1.2-dev`).

## 0.1.0-dev

**Phase 1 complete.** This release consolidates the full first phase
of the roadmap: cryptographic fundamentals, from raw entropy through
a unified wallet API, closed with a full error-handling and test
suite audit.

### Added

- `XrplSecp256k1.deriveIntermediateKeyPair`: validates that
  `rootPublicKey` is exactly 33 bytes, throwing `XrplCryptoException`
  otherwise (previously unvalidated on this public method)
- 2 new tests confirming error propagation through previously
  untested layers: `XrplWallet.fromSeed` with a corrupted seed, and
  `XrplSeed.fromBase58` with an invalid base58 character (93 tests
  total, up from 91)

### Fixed

- `XrplBase58._base`: corrected a doc comment copy-pasted from the
  `alphabet` field above it
- `XrplSecp256k1`: 2 doc comments describing the root/intermediate
  combination as "not yet implemented" corrected to reference
  `deriveKeyPair`, which already implements it
- `XrplEd25519`: doc comment describing `XrplWallet`'s unified API as
  a future plan ("will expose") corrected to present tense

### Design Decisions

- Audited every file in `lib/src/` against three questions: missing
  edge cases, error message clarity, and documentation accuracy -
  three files needed no changes, confirming validation was built
  incrementally per sub-version rather than deferred to the end
- While fixing a doc comment, a real dartdoc cross-reference briefly
  introduced an import cycle between `xrpl_ed25519.dart` and
  `xrpl_wallet.dart`. Reverted; documented as a standing rule:
  `crypto/` and `codec/` never import from `wallet/`
- This audit closes directly into `0.1.0-dev` rather than publishing
  an intermediate `0.0.6-dev` first, since the code would have been
  identical between the two releases

### Phase 1 Summary

- `XrplEntropy`, `XrplBase58`, `XrplSeed`, `XrplKeyAlgorithm`,
  `XrplHash`, `XrplSecp256k1`, `XrplEd25519`, `XrplWallet`
- 93 tests, verified against official specs and independently
  computed vectors (Python `hashlib`, `ecdsa`, `pynacl`) throughout
- No network interaction yet - that begins in Phase 2/3

### Status

**Phase 1 complete.** Not ready for production use.  
Next: Phase 2 - Addresses (`0.1.1-dev`).

## 0.0.5-dev

Phase 1 in progress: XrplWallet, the unified public API tying
together seed generation and key derivation for both algorithms.

### Added

- `XrplWallet`, in a new `lib/src/wallet/` folder (sibling to
  `crypto/`, `codec/`, `exceptions/` - not nested under `crypto/`,
  since a wallet is the layer that combines those, not a
  cryptographic primitive itself):
  - `XrplWallet.generate({required algorithm})`
  - `XrplWallet.fromSeed(value, {required algorithm})`
  - `publicKeyBytes` / `privateKeyBytes`: always plain `Uint8List`
    regardless of algorithm (33 and 32 bytes respectively), even
    though `secp256k1` and `Ed25519` use different underlying private
    key types (`BigInt` vs `Uint8List`) internally
- Algorithm-mismatch protection in `fromSeed()`: an `sEd`-declared
  (Ed25519) seed used with a mismatched requested algorithm throws
  `XrplCryptoException` instead of silently deriving the wrong key
  pair - the validation this SDK left as a known gap since
  `0.0.3-dev` is now closed
- 14 new unit tests (81 -> 90), including two full, real vectors
  chained end-to-end through `XrplWallet` (not just its building
  blocks): the same official secp256k1 seed
  (`sn259rEFXrQrWyx3Q7XneWcwV6dfL`) and Ed25519 seed
  (`sEdTM1uX8pu2do5XvTnutH6HsouMaM2`) already verified in earlier
  sub-versions

### Design Decisions

- Public and private keys are exposed only as unified `Uint8List`
  bytes - the SDK deliberately does not also expose each algorithm's
  original type (`BigInt` for secp256k1) alongside the unified bytes.
  If a concrete need for that surfaces later, it will be added then,
  with real context, rather than speculatively now
- `XrplWallet`'s public API is uniformly asynchronous
  (`Future<XrplWallet>`) regardless of algorithm, even though
  secp256k1 derivation is actually synchronous internally - this
  hides the sync/async split between `XrplSecp256k1` and
  `XrplEd25519` (documented in
  `docs-sdk/phase-1/key-derivation/`) behind one consistent API

### Status

Phase 1 in progress: entropy, base58 codec, family seed encoding, key
derivation (both algorithms), and the unified `XrplWallet` API
complete and tested.  
No network interaction yet (that begins in Phase 3).  
Not ready for production use.  
Next: error handling and validation review (`0.0.6-dev`).  

## 0.0.4-dev

Phase 1 in progress: key pair derivation for both secp256k1 and
Ed25519, the last cryptographic building block before XrplWallet.

### Added

- `XrplHash.sha512Half`: shared SHA-512Half hashing utility used
  throughout key derivation
- `XrplSecp256k1`: full official algorithm - `deriveRootKeyPair`,
  `deriveIntermediateKeyPair`, and `deriveKeyPair` (the combined
  master key pair), using `pointycastle`'s `ECDomainParameters`
- `XrplEd25519`: `deriveKeyPair`, using `package:cryptography`
- 17 new unit tests (64 -> 81). Every derivation step is checked
  against a real vector independently computed via Python
  (`hashlib`, the `ecdsa` library, and `pynacl`/libsodium), not just
  our own round-trip tests

### Changed

- Added a private constructor to `XrplBase58` to prevent
  instantiation of a static-only class, resolving the last `pana`
  documentation hint from a previous release

### Design Decisions

- `XrplSecp256k1` stays synchronous (`pointycastle`); `XrplEd25519`
  is asynchronous (`package:cryptography`). This isn't a style
  choice - `package:cryptography` does not support secp256k1 at all
  (only Ed25519, X25519, and NIST curves P-256/P-384/P-521), so the
  two algorithms cannot share one library here
- Chose `package:cryptography` (actively maintained) over
  `ed25519_edwards` (synchronous, but unmaintained for ~4 years) or
  `edwards25519` (maintained, but a low-level curve library that
  would require implementing key derivation from scratch on top of
  it) - correctness and maintenance outweighed API symmetry
- `XrplWallet` (`0.0.5-dev`) will expose a single, uniformly
  asynchronous public API regardless of algorithm, wrapping
  secp256k1's already-synchronous path rather than reimplementing it

### Status

Phase 1 in progress: entropy, base58 codec, family seed encoding, and
full key pair derivation (both algorithms) complete and tested
against official/independent vectors.  
No network interaction yet (that begins in Phase 3).  
Not ready for production use.  
Next: `XrplWallet`, the unified public API (`0.0.5-dev`).

## 0.0.3-dev

Phase 1 in progress: family seed encoding implemented, combining
entropy and the base58 codec into real, verifiable XRPL seeds.

### Added

- `XrplKeyAlgorithm`: enum for the two XRPL signing algorithms
  (`secp256k1`, `ed25519`), shared across seed encoding and the
  upcoming key derivation step
- `XrplSeed.generate(algorithm:)`: generates a new random seed;
  `algorithm` is a required parameter, matching the SDK-wide rule
  that the signing algorithm is never inferred silently
- `XrplSeed.fromBase58(value)`: decodes and checksum-verifies a seed
  string, recognizing both the generic `0x21` prefix and the
  Ed25519-declaring `sEd...` (`0x01 0xE1 0x4B`) prefix
- `XrplSeed.toBase58()`: encodes a seed back to its string form
- 16 new unit tests (43 -> 59), including 4 test vectors taken
  directly from the official `ripple-address-codec` test suite (3
  Ed25519, 1 secp256k1), independently re-verified via a standalone
  Python re-implementation before use

### Design Decisions

- Seeds support **both** known XRPL prefixes rather than only the
  generic one, so seeds generated by this SDK self-describe their
  algorithm to other XRPL tools (wallets, explorers, other SDKs) and
  avoid the same "same seed, different address" ambiguity problem at
  the interoperability level, not just within this SDK
- There is no dedicated secp256k1 prefix in the XRPL specification
  (only Ed25519 has one), so `declaredAlgorithm` is `null` for
  secp256k1 seeds, not an explicit enum value

### Fixed

- An initial implementation used an incorrect 2-byte Ed25519 prefix
  (`0x01 0xE1`), based on a misread of a manually decoded seed.
  Caught during verification against the official
  `ripple-address-codec` source and a real published seed - the
  correct prefix is 3 bytes (`0x01 0xE1 0x4B`). Fixed before merging,
  and the test suite now uses official test vectors instead of a
  manually-derived one to prevent a repeat.

### Status

Phase 1 in progress: entropy, base58 codec, and family seed encoding
complete and tested against official vectors. No network interaction
yet (that begins in Phase 3).  
Not ready for production use.  
Next: secp256k1 and Ed25519 key pair derivation (`0.0.4-dev`).  

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
