/// The XRP Ledger networks this SDK can connect to, and the official
/// public WebSocket server for each one.
///
/// Why this exists: `XrplNetwork` (in `address/`) already represents
/// Mainnet vs. Testnet, but only for the two networks that have a
/// distinct X-address prefix defined by the XLS-5d specification.
/// Devnet has no such prefix, so it has no meaningful place in that
/// enum. Connecting to a server, on the other hand, genuinely needs
/// a third option - Devnet is where new, experimental ledger
/// features are tested before they reach Testnet or Mainnet. Rather
/// than stretching `XrplNetwork` to cover a case its own
/// specification doesn't define, this is a separate, purpose-built
/// type for "which server do I talk to."
///
/// The URLs below are Ripple's own public servers, intended for
/// development and testing, not sustained production use - see the
/// official servers page for alternatives and caveats.
///
/// See: https://xrpl.org/docs/tutorials/public-servers
enum XrplEndpoint {
  /// The production XRP Ledger network.
  mainnet,

  /// The primary public test network. Funds here have no real-world
  /// value.
  testnet,

  /// A network for testing experimental features before they reach
  /// Testnet or Mainnet. Funds here have no real-world value, and
  /// this network can be reset or diverge more often than Testnet.
  devnet;

  /// The official public WebSocket URL for this network.
  ///
  /// Example:
  /// ```dart
  /// print(XrplEndpoint.testnet.websocketUrl);
  /// // wss://s.altnet.rippletest.net:51233/
  /// ```
  String get websocketUrl {
    switch (this) {
      case XrplEndpoint.mainnet:
        return 'wss://xrplcluster.com/';
      case XrplEndpoint.testnet:
        return 'wss://s.altnet.rippletest.net:51233/';
      case XrplEndpoint.devnet:
        return 'wss://s.devnet.rippletest.net:51233/';
    }
  }
}
