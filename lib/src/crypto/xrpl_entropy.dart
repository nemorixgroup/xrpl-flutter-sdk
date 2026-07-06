import 'dart:math';
import 'dart:typed_data';

import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';

/// Cryptographically secure entropy used as the basis for an XRPL seed.
///
/// The XRP Ledger requires exactly 16 bytes (128 bits) of entropy to
/// generate a family seed, regardless of which signing algorithm
/// (secp256k1 or Ed25519) is later derived from it. This matches the
/// behavior of the official `xrpl-keypairs` library maintained by
/// Ripple, which documents that entropy "must be 16 bytes long" when
/// provided explicitly.
///
/// Uses `dart:math`'s [Random.secure] rather than `dart:io`, so this
/// class works unmodified on mobile, desktop, and (in the future) web.
///
/// Example:
/// ```dart
/// final entropy = XrplEntropy.generate();
/// print(entropy.bytes.length); // 16
/// ```
class XrplEntropy {
  XrplEntropy._(this.bytes);

  /// Generates new, cryptographically secure random entropy.
  ///
  /// Example:
  /// ```dart
  /// final entropy = XrplEntropy.generate();
  /// ```
  factory XrplEntropy.generate() {
    final random = Random.secure();
    final generated = Uint8List(lengthInBytes);
    for (var i = 0; i < lengthInBytes; i++) {
      generated[i] = random.nextInt(256);
    }
    return XrplEntropy._(generated);
  }

  /// Wraps existing entropy bytes, validating their length.
  ///
  /// Useful for restoring a wallet from previously saved entropy, or
  /// for testing against official test vectors.
  ///
  /// Throws an [XrplCryptoException] if [bytes] is not exactly
  /// [lengthInBytes] long.
  ///
  /// Example:
  /// ```dart
  /// final entropy = XrplEntropy.fromBytes(Uint8List(16));
  /// ```
  factory XrplEntropy.fromBytes(Uint8List bytes) {
    validate(bytes);
    return XrplEntropy._(Uint8List.fromList(bytes));
  }

  /// Validates that [bytes] has the length required for XRPL entropy.
  ///
  /// Throws an [XrplCryptoException] if the length does not match
  /// [lengthInBytes].
  static void validate(Uint8List bytes) {
    if (bytes.length != lengthInBytes) {
      throw XrplCryptoException(
        'Entropy must be exactly $lengthInBytes bytes, got ${bytes.length}',
      );
    }
  }

  /// The number of bytes an XRPL seed's entropy must contain.
  static const int lengthInBytes = 16;

  /// The raw entropy bytes. Always exactly [lengthInBytes] long.
  final Uint8List bytes;
}
