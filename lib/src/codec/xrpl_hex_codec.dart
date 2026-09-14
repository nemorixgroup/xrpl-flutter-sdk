import 'dart:typed_data';

/// Converts between raw bytes and their uppercase hexadecimal string
/// representation - the format XRPL uses for `tx_blob`,
/// `SigningPubKey`, `TxnSignature`, and transaction hashes.
///
/// Why this exists: this exact conversion was being written
/// independently in multiple places across this SDK
/// (`xrpl_signer.dart`, `xrpl_transaction_hash.dart`,
/// `xrpl_submit_and_wait.dart`, and `xrpl_binary_primitives.dart`).
/// Consolidated here, alongside `XrplBase58`, as a general-purpose
/// codec - not specific to transactions or any other single feature
/// area, since bytes-to-hex is a basic need that could arise anywhere
/// in the SDK.
class XrplHexCodec {
  const XrplHexCodec._();

  /// Converts [bytes] to an uppercase hex string, per XRPL's
  /// convention (as opposed to lowercase, which is equally valid hex
  /// but not what XRPL's own tooling and documentation display).
  static String bytesToHex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString().toUpperCase();
  }

  /// Converts a hex string [hex] back to raw bytes. Case-insensitive.
  static Uint8List hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}
