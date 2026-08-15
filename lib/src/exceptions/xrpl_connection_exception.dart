/// Exception thrown when something goes wrong communicating with an
/// XRPL server: the connection itself fails, drops, times out, or
/// the server responds with an error.
///
/// Why this is separate from `XrplCryptoException`: everything this
/// SDK has done up to Phase 3 is offline, deterministic math - a
/// `XrplCryptoException` always means "the input or data itself is
/// wrong" (a bad checksum, an invalid length). A connection problem
/// is a different kind of failure entirely - the input can be
/// perfectly valid and the request can still fail because a server
/// is unreachable, slow, or temporarily overloaded. Keeping these as
/// distinct exception types lets calling code tell "my data is bad"
/// apart from "the network didn't cooperate," and react to each
/// appropriately (for example, retrying a connection failure rarely
/// makes sense for a cryptographic validation error).
///
/// Example:
/// ```dart
/// try {
///   await client.request('account_info', {'account': address});
/// } on XrplConnectionException catch (e) {
///   print(e.message);
/// }
/// ```
class XrplConnectionException implements Exception {
  /// Creates a new [XrplConnectionException] with the given [message].
  const XrplConnectionException(this.message);

  /// A human-readable description of what went wrong.
  final String message;

  @override
  String toString() => 'XrplConnectionException: $message';
}
