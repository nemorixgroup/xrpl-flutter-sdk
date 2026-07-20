/// The two signing algorithms supported by the XRP Ledger.
///
/// The SDK always requires this to be specified explicitly wherever a
/// key pair is generated or derived - it is never inferred silently.
/// The same seed produces a completely different key pair (and a
/// completely different address) depending on which algorithm is
/// used, so guessing the wrong one would put funds at an address the
/// user did not intend.
enum XrplKeyAlgorithm {
  /// The original XRPL signing algorithm (`secp256k1`), historically
  /// the default used by `rippled` itself.
  secp256k1,

  /// The newer, faster signing algorithm (`Ed25519`), the default
  /// used by many client libraries such as `xrpl.js`.
  ed25519,
}
