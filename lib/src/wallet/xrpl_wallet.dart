import 'dart:typed_data';

import 'package:xrpl_flutter_sdk/src/crypto/xrpl_ed25519.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_key_algorithm.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_secp256k1.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_seed.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';

/// A complete XRPL wallet: a seed and its derived key pair, unified
/// behind a single API regardless of which signing algorithm is used.
///
/// The algorithm is always an explicit, required parameter - never
/// inferred - consistent with every other type in this SDK.
///
/// The public and private keys are always exposed as plain
/// [Uint8List] bytes, even though `secp256k1` and `Ed25519` use
/// different underlying types internally (`BigInt` vs `Uint8List`
/// for the private key). This SDK deliberately does not also expose
/// each algorithm's original type alongside the unified bytes - if a
/// concrete need for that arises later, it can be added then, with
/// real context, rather than speculatively now.
///
/// The public API is uniformly asynchronous (`Future<XrplWallet>`),
/// even though `secp256k1` derivation ([XrplSecp256k1]) is actually
/// synchronous - only `Ed25519` derivation ([XrplEd25519]) genuinely
/// needs to be async, because it depends on `package:cryptography`.
/// See `docs-sdk/phase-1/key-derivation/` for why that library
/// difference exists and can't be resolved by switching libraries.
class XrplWallet {
  const XrplWallet._({
    required this.seed,
    required this.algorithm,
    required this.publicKeyBytes,
    required this.privateKeyBytes,
  });

  /// The seed this wallet was generated from or restored with.
  final XrplSeed seed;

  /// The signing algorithm this wallet's key pair uses.
  final XrplKeyAlgorithm algorithm;

  /// The public key, always 33 bytes: `secp256k1`'s compressed form,
  /// or `Ed25519`'s 32-byte public key prefixed with `0xED`.
  final Uint8List publicKeyBytes;

  /// The private key, always 32 bytes, regardless of algorithm.
  final Uint8List privateKeyBytes;

  /// Generates a brand new wallet for the given [algorithm].
  ///
  /// Example:
  /// ```dart
  /// final wallet = await XrplWallet.generate(
  ///   algorithm: XrplKeyAlgorithm.ed25519,
  /// );
  /// ```
  static Future<XrplWallet> generate({
    required XrplKeyAlgorithm algorithm,
  }) async {
    final seed = XrplSeed.generate(algorithm: algorithm);
    return _deriveFrom(seed, algorithm);
  }

  /// Restores a wallet from a previously saved seed [value].
  ///
  /// Throws an [XrplCryptoException] if [value]'s checksum is invalid
  /// (via [XrplSeed.fromBase58]), or if the seed explicitly declares
  /// an algorithm (via the `sEd...` prefix) that contradicts the
  /// requested [algorithm] - this is never allowed to fail silently.
  ///
  /// Example:
  /// ```dart
  /// final wallet = await XrplWallet.fromSeed(
  ///   'sEdTNFV69uSpcHpCppa6VzMvmC68CVY',
  ///   algorithm: XrplKeyAlgorithm.ed25519,
  /// );
  /// ```
  static Future<XrplWallet> fromSeed(
    String value, {
    required XrplKeyAlgorithm algorithm,
  }) async {
    final seed = XrplSeed.fromBase58(value);

    if (seed.declaredAlgorithm != null && seed.declaredAlgorithm != algorithm) {
      throw XrplCryptoException(
        'Seed declares algorithm ${seed.declaredAlgorithm}, but '
        '$algorithm was requested',
      );
    }

    return _deriveFrom(seed, algorithm);
  }

  static Future<XrplWallet> _deriveFrom(
    XrplSeed seed,
    XrplKeyAlgorithm algorithm,
  ) async {
    if (algorithm == XrplKeyAlgorithm.secp256k1) {
      final keyPair = XrplSecp256k1.deriveKeyPair(seed.entropy);
      return XrplWallet._(
        seed: seed,
        algorithm: algorithm,
        publicKeyBytes: keyPair.compressedPublicKey,
        privateKeyBytes: _bigIntToBytes(keyPair.privateKey, 32),
      );
    }

    final keyPair = await XrplEd25519.deriveKeyPair(seed.entropy);
    return XrplWallet._(
      seed: seed,
      algorithm: algorithm,
      publicKeyBytes: keyPair.prefixedPublicKey,
      privateKeyBytes: keyPair.privateKey,
    );
  }

  static Uint8List _bigIntToBytes(BigInt value, int length) {
    final result = Uint8List(length);
    var remaining = value;
    for (var i = length - 1; i >= 0; i--) {
      result[i] = (remaining & BigInt.from(0xff)).toInt();
      remaining = remaining >> 8;
    }
    return result;
  }
}
