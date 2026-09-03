import 'dart:typed_data';

import 'package:xrpl_flutter_sdk/src/codec/xrpl_base58.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';

/// Low-level binary encoders for XRPL's canonical serialization
/// format, for the specific field types `XrplPayment` and
/// `XrplTrustSet` need: `UInt16`, `UInt32`, `AccountID`, and `Blob`.
///
/// Why this exists: XRPL's binary format encodes every field type
/// differently (see `docs-sdk/phase-4/binary-serialization/`), and
/// each encoder here was verified against the exact byte layout in
/// an official worked example (an `OfferCreate` transaction's
/// published JSON and binary side by side) before being trusted,
/// following this SDK's standing practice of never accepting an
/// implementation on assumption alone.
///
/// See: https://xrpl.org/docs/references/protocol/binary-format
class XrplBinaryPrimitives {
  const XrplBinaryPrimitives._();

  /// Encodes XRPL's "length prefix" (also called VL, for "variable
  /// length"): 1 to 3 bytes indicating how many bytes of content
  /// follow, immediately before that content.
  ///
  /// This SDK's current fields only ever need the 1-byte form
  /// (content 0 to 192 bytes long, which covers a 20-byte AccountID
  /// and public keys/signatures well under that limit) - the 2-byte
  /// and 3-byte forms exist in the official specification for larger
  /// content this SDK doesn't serialize yet.
  ///
  /// Throws an [XrplCryptoException] if [length] exceeds what the
  /// 1-byte form can represent (192), since no field this SDK
  /// currently serializes should ever need more than that.
  static Uint8List encodeLengthPrefix(int length) {
    if (length < 0 || length > 192) {
      throw XrplCryptoException(
        'Length prefix encoding only supports 0-192 bytes in this SDK '
        '(the 1-byte form), got $length. Longer fields are not yet '
        'supported.',
      );
    }
    return Uint8List.fromList([length]);
  }

  /// Encodes a `UInt16` field: exactly 2 bytes, big-endian.
  static Uint8List encodeUInt16(int value) {
    final bytes = Uint8List(2);
    bytes.buffer.asByteData().setUint16(0, value);
    return bytes;
  }

  /// Encodes a `UInt32` field: exactly 4 bytes, big-endian.
  static Uint8List encodeUInt32(int value) {
    final bytes = Uint8List(4);
    bytes.buffer.asByteData().setUint32(0, value);
    return bytes;
  }

  /// Encodes an `AccountID` field: a classic [address] decoded back
  /// to its 20-byte Account ID, prefixed with its length (always
  /// `0x14`, 20, since an Account ID is always exactly 20 bytes).
  ///
  /// Reuses [XrplBase58]'s checksum-verified decoding rather than a
  /// separate implementation, so a mistyped address is rejected the
  /// same way it already is everywhere else in this SDK.
  ///
  /// Throws an [XrplCryptoException] if [address]'s checksum is
  /// invalid.
  static Uint8List encodeAccountId(String address) {
    final decoded = XrplBase58.decodeWithChecksum(address);
    // decodeWithChecksum returns the type prefix (0x00 for a classic
    // address) followed by the 20-byte Account ID - strip the prefix.
    final accountId = decoded.sublist(1);
    return Uint8List.fromList([
      ...encodeLengthPrefix(accountId.length),
      ...accountId,
    ]);
  }

  /// Encodes a `Blob` field: raw bytes from a [hexValue] string,
  /// prefixed with their length.
  static Uint8List encodeBlob(String hexValue) {
    final bytes = _hexToBytes(hexValue);
    return Uint8List.fromList([
      ...encodeLengthPrefix(bytes.length),
      ...bytes,
    ]);
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}
