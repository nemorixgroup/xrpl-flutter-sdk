import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';

/// Base58 encoding using the XRP Ledger's own alphabet.
///
/// This is **not** the same alphabet Bitcoin uses. XRPL rearranges the
/// characters so that common typos are caught early and so that the
/// encoding is visually distinct from Bitcoin addresses. Source:
/// the `ripple-address-codec` reference implementation used across
/// all official Ripple/XRPL client libraries.
///
/// This class only handles the base58 conversion itself. It does
/// **not** add or verify a checksum; that is a separate step used by
/// higher-level types like seeds and addresses, since not everything
/// encoded in base58 needs one.
class XrplBase58 {
  /// Private constructor
  const XrplBase58._();

  /// The XRPL base58 alphabet (58 characters, no `0`, `O`, `I`, or `l`).
  static const String alphabet =
      'rpshnaf39wBUDNEGHJKLM4PQRST7VWXYZ2bcdeCg65jkm8oFqi1tuvAxyz';

  /// The XRPL base58 alphabet (58 characters, no `0`, `O`, `I`, or `l`).
  static final BigInt _base = BigInt.from(58);

  /// Encodes raw [bytes] into an XRPL base58 string, with no checksum.
  ///
  /// Leading zero bytes are preserved as leading `alphabet[0]`
  /// characters (`'r'`), matching standard base58 behavior: each
  /// leading zero byte represents a leading zero in the underlying
  /// number, which base58 alone cannot express numerically.
  ///
  /// Example:
  /// ```dart
  /// final encoded = XrplBase58.encodeRaw(Uint8List.fromList([0, 1, 2]));
  /// ```
  static String encodeRaw(Uint8List bytes) {
    if (bytes.isEmpty) return '';

    // Count leading zero bytes; each becomes a leading alphabet[0] char.
    var leadingZeros = 0;
    while (leadingZeros < bytes.length && bytes[leadingZeros] == 0) {
      leadingZeros++;
    }

    // Convert the byte array to a single big integer.
    var value = BigInt.zero;
    for (final byte in bytes) {
      value = (value << 8) | BigInt.from(byte);
    }

    // Repeatedly divide by 58, collecting remainders as alphabet indices.
    final digits = <int>[];
    while (value > BigInt.zero) {
      final remainder = value % _base;
      digits.add(remainder.toInt());
      value = value ~/ _base;
    }

    final buffer = StringBuffer()..write(alphabet[0] * leadingZeros);
    for (final digit in digits.reversed) {
      buffer.write(alphabet[digit]);
    }
    return buffer.toString();
  }

  /// Decodes an XRPL base58 [encoded] string back into raw bytes, with
  /// no checksum verification. The exact inverse of [encodeRaw].
  ///
  /// Leading `alphabet[0]` characters (`'r'`) are converted back into
  /// leading zero bytes.
  ///
  /// Throws an [XrplCryptoException] if [encoded] contains any
  /// character outside the XRPL [alphabet].
  ///
  /// Example:
  /// ```dart
  /// final bytes = XrplBase58.decodeRaw('rrp'); // -> [0, 0, 1]
  /// ```
  static Uint8List decodeRaw(String encoded) {
    if (encoded.isEmpty) return Uint8List(0);

    // Count leading alphabet[0] characters; each becomes a zero byte.
    var leadingZeros = 0;
    while (
        leadingZeros < encoded.length && encoded[leadingZeros] == alphabet[0]) {
      leadingZeros++;
    }

    // Convert the base58 string to a single big integer.
    var value = BigInt.zero;
    for (var i = 0; i < encoded.length; i++) {
      final digit = alphabet.indexOf(encoded[i]);
      if (digit == -1) {
        throw XrplCryptoException(
          "Invalid XRPL base58 character '${encoded[i]}' at position $i",
        );
      }
      value = value * _base + BigInt.from(digit);
    }

    // Convert the big integer back to the minimal big-endian byte form.
    final bytes = <int>[];
    while (value > BigInt.zero) {
      bytes.insert(0, (value & BigInt.from(0xff)).toInt());
      value = value >> 8;
    }

    return Uint8List.fromList([
      ...List.filled(leadingZeros, 0),
      ...bytes,
    ]);
  }

  /// Decodes an XRPL base58 [encoded] string that was created with
  /// [encodeWithChecksum], verifying the embedded 4-byte checksum
  /// before returning the original data.
  ///
  /// This is the safety-critical counterpart to [decodeRaw]: it
  /// detects a mistyped or corrupted string (for example, a seed
  /// copied with one wrong character) and rejects it explicitly,
  /// instead of silently returning garbage data.
  ///
  /// Throws an [XrplCryptoException] if:
  /// - [encoded] contains a character outside the XRPL [alphabet]
  ///   (via [decodeRaw]), or
  /// - [encoded] decodes to fewer than 4 bytes (too short to contain
  ///   a checksum), or
  /// - the embedded checksum does not match the recomputed checksum
  ///   of the remaining data.
  ///
  /// Example:
  /// ```dart
  /// final data = XrplBase58.decodeWithChecksum(
  ///   XrplBase58.encodeWithChecksum(Uint8List.fromList([0x21, 1, 2, 3])),
  /// );
  /// ```
  static Uint8List decodeWithChecksum(String encoded) {
    final allBytes = decodeRaw(encoded);

    if (allBytes.length < 4) {
      throw XrplCryptoException(
        'Cannot verify checksum: decoded data is only '
        '${allBytes.length} byte(s), need at least 4',
      );
    }

    final data = allBytes.sublist(0, allBytes.length - 4);
    final receivedChecksum = allBytes.sublist(allBytes.length - 4);
    final expectedChecksum = checksumOf(data);

    for (var i = 0; i < 4; i++) {
      if (receivedChecksum[i] != expectedChecksum[i]) {
        throw const XrplCryptoException(
          'Checksum mismatch: this string may be corrupted or mistyped',
        );
      }
    }

    return data;
  }

  /// Encodes [bytes] into an XRPL base58 string with a 4-byte checksum
  /// appended, matching how XRPL seeds and addresses are encoded.
  ///
  /// The checksum is the first 4 bytes of the double SHA-256 hash of
  /// [bytes] (`SHA256(SHA256(bytes))`), the same scheme Bitcoin's
  /// `Base58Check` uses. It lets consumers detect a mistyped or
  /// corrupted string before attempting to use it, rather than
  /// silently accepting bad data.
  ///
  /// Example:
  /// ```dart
  /// final encoded = XrplBase58.encodeWithChecksum(
  ///   Uint8List.fromList([0x21, 1, 2, 3]),
  /// );
  /// ```
  static String encodeWithChecksum(Uint8List bytes) {
    final checksum = checksumOf(bytes);
    final withChecksum = Uint8List.fromList([...bytes, ...checksum]);
    return encodeRaw(withChecksum);
  }

  /// Computes the 4-byte XRPL/Bitcoin-style checksum for [bytes]:
  /// the first 4 bytes of `SHA256(SHA256(bytes))`.
  ///
  /// Exposed separately from [encodeWithChecksum] so it can be reused
  /// later (for example, to verify a checksum during decoding) without
  /// duplicating the hashing logic.
  static Uint8List checksumOf(Uint8List bytes) {
    final digest = SHA256Digest();
    final firstHash = digest.process(bytes);
    digest.reset();
    final secondHash = digest.process(firstHash);
    return secondHash.sublist(0, 4);
  }
}
