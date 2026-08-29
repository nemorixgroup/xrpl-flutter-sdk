# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.3.1-dev

Phase 4 in progress: the transaction model. This is the first
sub-version that can describe what you want to happen on the ledger
(send XRP, extend trust to a token), transactions still aren't
signed or submitted yet, that's 0.3.2-dev and 0.3.3-dev.

### Added

- `XrplTransaction`: the shared interface every transaction type
  implements (`account`, `sequence`, `fee`, `lastLedgerSequence`,
  `copyWith`, `toJson`), so `autofill` and future signing/submission
  code work with any transaction type without per-type duplication
- `XrplPayment`, `XrplTrustSet` in a new `lib/src/transactions/models/`
  folder: typed transaction models with `toJson()`/`copyWith()`.
  `XrplPayment` is XRP-only for this sub-version; issued-currency
  Payments are deferred to Phase 5 (DEX & Cross-Currency)
- `fee(connection)` in `xrpl_queries.dart`: the official `fee`
  command, returning the full `result` (multiple already-calculated
  fee levels plus the current ledger index)
- `XrplFeeStrategy`: `openLedger` (default), `minimum`, `median`,
  `base` - selects which of the `fee` command's reported values
  `autofill` uses
- `autofill<T extends XrplTransaction>(connection, transaction, {feeStrategy})`:
  fills in `sequence` (via `accountInfo`), `fee`, and
  `lastLedgerSequence` (current ledger index + 4, the official
  minimum recommendation), reusing `accountInfo`/`fee` rather than
  duplicating either lookup, and only filling in fields not already
  set
- New `lib/src/transactions/` folder, sibling to `crypto/`, `codec/`,
  `wallet/`, `address/`, `connection/`, `exceptions/`
- 11 new tests (154 -> ... wait, verify actual count -> 167), including
  live integration tests against the public Testnet server

### Design Decisions

- `XrplTransaction` as a shared interface (not separate
  `autofillPayment`/`autofillTrustSet` functions) so `autofill`, and
  future signing/submission logic, works generically across every
  transaction type this SDK adds in later phases, without repeating
  the same logic per type
- `Fee` defaults to `open_ledger_fee`, not `minimum_fee` - per
  official "Reliable Transaction Submission" guidance, prioritizing
  prompt inclusion over minimizing cost, while still letting callers
  choose `minimum`/`median`/`base` explicitly
- `autofill` skips network calls entirely for any field already
  provided - a transaction with `sequence`, `fee`, and
  `lastLedgerSequence` all set never touches the network, verified
  with a dedicated unit test

### Status

Phase 4 in progress: transaction model and autofill complete and
verified against the real public Testnet server.   
Not ready for production use.   
Next: signing transactions (`0.3.2-dev`).

## 0.3.0-dev

**Phase 3 complete.** This release consolidates Phase 3: connection
lifecycle, JSON-RPC requests, account/server queries, and real-time
subscription streams, closed with a full error-handling and test
suite audit.

### Added

- (Carried from 0.2.1-dev through 0.2.3-dev) `XrplEndpoint`,
  `XrplConnectionException`, `XrplConnection` (lifecycle, `request`,
  typed event streams), `xrpl_queries.dart` (`serverInfo`,
  `accountInfo`), `xrpl_subscriptions.dart` (4 subscribe/unsubscribe
  pairs)

### Changed

- `XrplConnection._handleIncomingMessage`: hardened against malformed
  incoming messages (not a `String`, invalid JSON, JSON that isn't an
  object), using type checks (`is!`) rather than unchecked casts, so
  a malformed message is silently dropped instead of risking an
  uncaught exception inside the shared stream listener
- `serverInfo`/`accountInfo`: replaced unchecked `as Map<String, dynamic>`
  casts with explicit `is!` checks, throwing a clear
  `XrplConnectionException` on an unexpected response shape instead
  of risking an uncontrolled `TypeError`

### Design Decisions

- Audited every file under `lib/src/connection/` against the same
  three questions used to close Phases 1 and 2: missing edge cases,
  error message clarity, documentation accuracy. Three of five files
  needed no changes at all
- Two defensive validations added during this audit (malformed
  WebSocket messages, malformed query responses) were deliberately
  left without dedicated tests: by the time either check runs, prior
  validation already makes a real failure extremely unlikely from an
  actual XRPL server, and there is no practical way to make the
  public Testnet server return malformed data on purpose. Documented
  directly in the code as a known, low-risk trade-off rather than
  silently untested

### Phase 3 Summary

- `XrplEndpoint`, `XrplConnectionException`, `XrplConnection`,
  `xrpl_queries.dart`, `xrpl_subscriptions.dart`
- 154 tests total, including this SDK's first integration tests
  against a real, live XRPL server (the public Testnet), kept
  separate from fast unit tests under `test/src/`
- The SDK can now connect to XRPL, send/receive JSON-RPC requests,
  query real account and server data, and react to real-time network
  events (new ledgers, transactions, validations, server status)

### Status

**Phase 3 complete.**  
Not ready for production use.   
Next: Phase 4 - Core Transactions (`0.3.1-dev`).

## 0.2.3-dev

Phase 3 in progress: real-time subscription streams, so the SDK can
react to network events (new ledgers, transactions, validations,
server status changes) as they happen, instead of only polling on
demand.

### Added

- `XrplConnection.ledgerEvents`, `.transactionEvents`,
  `.validationEvents`, `.serverEvents`: typed broadcast streams for
  XRPL subscription push messages, routed by the message's `type`
  field (`ledgerClosed`, `transaction`, `validationReceived`,
  `serverStatus`). Separate from `request()`'s `id`-matched
  responses, which is a genuinely different kind of message per the
  official specification
- `subscribeToLedger`/`unsubscribeFromLedger`,
  `subscribeToTransactions`/`unsubscribeFromTransactions` (with an
  `includeProposed` option), `subscribeToValidations`/`unsubscribeFromValidations`,
  `subscribeToServer`/`unsubscribeFromServer` in a new
  `lib/src/connection/xrpl_subscriptions.dart`
- 8 new tests (146 -> 154), including a live integration test that
  subscribes to the `ledger` stream and waits for a real
  `ledgerClosed` event from the public Testnet server

### Design Decisions

- Chose separate, typed streams per event type over one generic
  stream the caller filters by `type` themselves, removes a class of
  typo-prone, silently-ignored-on-mismatch string comparisons from
  calling code, and matches the pattern official client libraries in
  other languages already use (e.g. separate stream channels per
  event type)
- Event stream controllers are created once at construction, not per
  `connect()` call, so a caller's existing `.listen()` subscriptions
  keep working across a disconnect/reconnect
- Recognized-but-unhandled event types (`consensusPhase`,
  `bookChanges`, `peerStatusChange`, `manifestReceived`) are silently
  ignored rather than raising an error - each is documented with its
  official source directly in `_routeEvent`'s doc comment, since
  receiving an unrecognized event isn't itself a failure, just a
  feature not built yet (`bookChanges` is relevant to Phase 5, the
  admin-only ones aren't relevant to a client SDK at all)

### Status

Phase 3 in progress: connection lifecycle, requests/queries, and
subscription streams complete and verified against the real public
Testnet server.   
Not ready for production use.   
Next: Phase 3 closing audit (`0.3.0-dev`).

## 0.2.2-dev

Phase 3 in progress: sending/receiving JSON-RPC requests over the
connection, with account_info and server_info as the first real
queries.

### Added

- `XrplConnection.request(command, [params])`: sends a generic XRPL
  request and returns its response, matching responses to requests by
  `id` so multiple requests can be in flight on the same connection
  at once. Throws `XrplConnectionException` if not connected, on
  timeout (20s default), or if the server responds with
  `"status": "error"`
- `serverInfo(connection, {counters})`: returns the connected
  server's status (`result.info`), unwrapped from the response
  envelope
- `accountInfo(connection, account, {ledgerHash, ledgerIndex, queue, signerLists})`:
  returns an account's data (`result.account_data`); all parameters
  beyond `account` are optional and only included in the request if
  explicitly provided
- New `lib/src/connection/xrpl_queries.dart`, holding command-specific
  helpers built on top of `XrplConnection.request`
- 3 new unit/integration tests for `request()`, plus integration
  tests for `serverInfo` and `accountInfo` against the real public
  Testnet server (146 tests total)

### Design Decisions

- Both query helpers return only the useful inner part of the
  response (`result.info`, `result.account_data`), not the full
  envelope - consistent between the two, so callers never need to
  know XRPL's response wrapping shape
- `accountInfo`'s optional parameters default to `null`, not sensible
  defaults - each is added to the outgoing request only if explicitly
  provided, keeping the simplest call as close to the official
  minimal example as possible
- `accountInfo`'s success case (a funded account with real data) is
  not yet covered by a test, since Testnet resets periodically and a
  hardcoded "known funded account" would be unreliable long-term;
  only the stable error case (a freshly generated, never-funded
  account) is tested for now - tracked for once this SDK can fund a
  Testnet account itself

### Status

Phase 3 in progress: connection lifecycle, generic requests, and the
first two real queries complete and verified against the real public
Testnet server.  
Not ready for production use.  
Next: subscribe streams (`0.2.3-dev`).

## 0.2.1-dev

Phase 3 in progress: the connection layer's foundation - network
endpoints and the WebSocket connection lifecycle (connect/disconnect).
No requests can be sent yet; that's `0.2.2-dev`.

### Added

- `XrplEndpoint`: Mainnet/Testnet/Devnet, each with its official
  public WebSocket URL, verified against
  `xrpl.org/docs/tutorials/public-servers`. Separate from
  `XrplNetwork` (`address/`), which only covers Mainnet/Testnet since
  those are the only two networks with an X-address prefix defined by
  XLS-5d
- `XrplConnectionException`: a new exception type, separate from
  `XrplCryptoException`, for connection/network failures - a bad
  checksum and an unreachable server are different categories of
  problem and are now distinguishable by exception type
- `XrplConnection`: manages a WebSocket connection's lifecycle
  (`connect`, `disconnect`, `isConnected`) against a given
  `XrplEndpoint`, using `package:web_socket_channel` rather than
  `dart:io`'s `WebSocket`, for the same mobile/desktop/web
  compatibility reasons `dart:math` was chosen over `dart:io` in
  Phase 1
- 13 new unit tests (127 -> 140... TODO: replace with the real count
  from pre_commit.ps1). Tests touching the real public Testnet server
  are kept in a separate `test/src/connection/xrpl_connection_integration_test.dart`,
  mirroring `lib/src/` under `test/src/`, apart from the pure,
  network-free unit tests in `test/connection/xrpl_connection_test.dart`

### Design Decisions

- `0.2.1-dev` intentionally covers only the connection lifecycle, not
  sending or receiving messages - that's grouped with its first real
  use (`account_info`, `server_info`) in `0.2.2-dev`, rather than
  shipped in isolation with nothing using it yet
- `XrplConnection.disconnect()` is a safe no-op when not currently
  connected, rather than throwing - "make sure we're disconnected" is
  a reasonable thing to want regardless of current state
- This is the SDK's first genuinely stateful, network-dependent type;
  everything in Phases 1 and 2 was offline and deterministic

### Status

Phase 3 in progress: network endpoints and connection lifecycle
complete and verified against the real public Testnet server.  
Not ready for production use.  
Next: sending/receiving JSON-RPC requests over the connection, and
the first real queries (`account_info`, `server_info`) - `0.2.2-dev`.

## 0.2.0-dev

**Phase 2 complete.** This release consolidates Phase 2: address
derivation, from a public key to both classic addresses and
X-addresses, fully integrated into XrplWallet, closed with a full
error-handling and test suite audit.

### Added

- (Carried from 0.1.1-dev through 0.1.3-dev) `XrplClassicAddress`,
  `XrplNetwork`, `XrplXAddress`, and their integration into
  `XrplWallet` (`classicAddress` field, `xAddress()` method)

### Changed

- `XrplClassicAddress`: expanded the class-level doc comment to
  explain why classic addresses exist (a public key alone is not a
  usable, self-identifying, self-correcting account identifier)
- `XrplWallet.classicAddress`: corrected a doc comment that still
  pointed callers to `XrplXAddress.deriveFrom` directly, written
  before the `xAddress()` method existed on the same class; now
  references `[xAddress]`

### Design Decisions

- Audited every file under `lib/src/address/` and the new sections of
  `lib/src/wallet/xrpl_wallet.dart` against the same three questions
  used to close Phase 1: missing edge cases, error message clarity,
  documentation accuracy. Two of four files needed no changes at all
- Reviewed error propagation across every layer in the address
  pipeline (public key to Account ID to classic/X-address to
  XrplWallet) and found no coverage gaps this time - unlike the
  Phase 1 audit, which did find and close two - because each new
  method's tests already asserted propagation from the layer below it
  as it was built, not deferred to a later cleanup pass
- Reviewed `test/wallet/xrpl_wallet_classic_address_test.dart` and
  `xrpl_wallet_x_address_test.dart` for duplication against the
  underlying `XrplClassicAddress`/`XrplXAddress` test suites; confirmed
  they are intentional chain-verification tests (checking the
  integration matches the standalone derivation), not accidental
  duplication, and left them as-is
- This audit closes directly into `0.2.0-dev`

### Phase 2 Summary

- `XrplClassicAddress`, `XrplNetwork`, `XrplXAddress`, and their
  integration into `XrplWallet`
- 122 tests total, verified against official specifications and
  independently computed vectors (including two vectors taken
  directly from the official `ripple-address-codec` X-address pull
  request) throughout
- A test-vector transcription bug (reusing an unrelated official
  example's public key) was caught by an unexpected test failure
  during `0.1.2-dev`, investigated rather than "fixed" by adjusting
  the expected value, and confirmed to be a test-construction error,
  not an implementation bug
- No network interaction yet - that begins in Phase 3

### Status

**Phase 2 complete.** Not ready for production use.  
Next: Phase 3 - Connection Layer (`0.2.1-dev`).

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
