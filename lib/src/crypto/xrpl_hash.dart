import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Shared hashing utilities used across XRPL key derivation.
class XrplHash {
  const XrplHash._();

  /// Computes "SHA-512Half": the SHA-512 hash of [bytes], truncated to
  /// its first 32 bytes (256 bits).
  ///
  /// This is the hash function XRPL uses throughout key derivation
  /// (for both the secp256k1 root/intermediate key pair steps and the
  /// Ed25519 secret key) instead of plain SHA-256, per the official
  /// specification: "the SHA-512Half of the seed value... the
  /// result is the 32-byte secret key."
  ///
  /// Example:
  /// ```dart
  /// final halfHash = XrplHash.sha512Half(someBytes);
  /// print(halfHash.length); // 32
  /// ```
  static Uint8List sha512Half(Uint8List bytes) {
    final digest = SHA512Digest();
    final fullHash = digest.process(bytes);
    return fullHash.sublist(0, 32);
  }
}
