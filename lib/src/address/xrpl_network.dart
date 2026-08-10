/// The XRP Ledger networks an X-address can be encoded for.
///
/// XRPL runs multiple independent networks that share the same
/// protocol but are not interoperable with each other: the production
/// network (Mainnet) and one or more test networks (Testnet, and
/// later Devnet in Phase 3). X-addresses embed which network they're
/// intended for directly in the address string (a different leading
/// character, `X` vs `T`), so that copying a Testnet address into a
/// Mainnet context - or vice versa - is visibly wrong instead of a
/// silent mistake.
///
/// See: https://github.com/XRPLF/XRPL-Standards/discussions/6
/// (XLS-5d: Standard for Tagged Addresses)
enum XrplNetwork {
  /// The production XRP Ledger network. X-addresses for this network
  /// start with `X`.
  mainnet,

  /// A test network (Testnet). X-addresses for this network start
  /// with `T`. Funds on test networks have no real-world value.
  testnet,
}
