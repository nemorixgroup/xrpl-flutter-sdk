/// Exception thrown when a cryptographic operation in the XRPL SDK
/// receives invalid input or fails an internal invariant check.
///
/// Example:
/// ```dart
/// try {
///   XrplEntropy.validate(Uint8List(8)); // wrong length
/// } on XrplCryptoException catch (e) {
///   print(e.message); // "Entropy must be exactly 16 bytes, got 8"
/// }
/// ```
class XrplCryptoException implements Exception {
  /// Creates a new [XrplCryptoException] with the given [message].
  const XrplCryptoException(this.message);

  /// A human-readable description of what went wrong.
  final String message;

  @override
  String toString() => 'XrplCryptoException: $message';
}
