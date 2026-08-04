import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'package:xrpl_flutter_sdk/src/codec/xrpl_base58.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';

/// Derives an XRPL classic address ("r...") from a public key.
///
/// A classic address is a base58, checksummed encoding of a 20-byte
/// "Account ID", which is itself derived from a public key via
/// RIPEMD-160(SHA-256(publicKey)).
///
/// See: https://xrpl.org/docs/concepts/accounts/addresses#address-encoding
class XrplClassicAddress {
  const XrplClassicAddress._();

  /// The one-byte "type prefix" XRPL uses to distinguish classic
  /// addresses from other base58-encoded values (seeds, node public
  /// keys, etc.) when decoding.
  static const int typePrefix = 0x00;

  /// The length, in bytes, a public key must be to derive an address
  /// from it: 33 bytes, whether it's a compressed secp256k1 public
  /// key or an Ed25519 public key prefixed with `0xED`.
  static const int expectedPublicKeyLength = 33;

  /// The length, in bytes, of a derived Account ID (a RIPEMD-160
  /// hash is always 160 bits).
  static const int accountIdLength = 20;

  /// Derives the 20-byte Account ID from a [publicKey]:
  /// `RIPEMD160(SHA256(publicKey))`.
  ///
  /// Throws an [XrplCryptoException] if [publicKey] is not exactly
  /// [expectedPublicKeyLength] bytes.
  ///
  /// Example:
  /// ```dart
  /// final accountId = XrplClassicAddress.accountIdFromPublicKey(publicKey);
  /// print(accountId.length); // 20
  /// ```
  static Uint8List accountIdFromPublicKey(Uint8List publicKey) {
    if (publicKey.length != expectedPublicKeyLength) {
      throw XrplCryptoException(
        'publicKey must be exactly $expectedPublicKeyLength bytes '
        '(compressed secp256k1, or Ed25519 with the 0xED prefix), got '
        '${publicKey.length}',
      );
    }

    final sha256Digest = SHA256Digest();
    final innerHash = sha256Digest.process(publicKey);

    final ripemd160Digest = RIPEMD160Digest();
    return ripemd160Digest.process(innerHash);
  }

  /// Derives the full classic address (for example
  /// `"rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN"`) from a [publicKey].
  ///
  /// Combines [accountIdFromPublicKey] with the `0x00` type prefix
  /// and [XrplBase58.encodeWithChecksum], reusing the same
  /// checksummed base58 encoding already used for seeds.
  ///
  /// Throws an [XrplCryptoException] if [publicKey] is not exactly
  /// [expectedPublicKeyLength] bytes.
  ///
  /// Example:
  /// ```dart
  /// final address = XrplClassicAddress.deriveFrom(wallet.publicKeyBytes);
  /// ```
  static String deriveFrom(Uint8List publicKey) {
    final accountId = accountIdFromPublicKey(publicKey);
    final payload = Uint8List.fromList([typePrefix, ...accountId]);
    return XrplBase58.encodeWithChecksum(payload);
  }
}
