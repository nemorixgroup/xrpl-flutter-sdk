import 'dart:typed_data';

import 'package:xrpl_flutter_sdk/src/address/xrpl_classic_address.dart';
import 'package:xrpl_flutter_sdk/src/address/xrpl_network.dart';
import 'package:xrpl_flutter_sdk/src/address/xrpl_x_address.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_ed25519.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_key_algorithm.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_secp256k1.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_seed.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';

/// A complete XRPL wallet: a seed, its derived key pair, and its
/// classic address, unified behind a single API regardless of which
/// signing algorithm is used.
///
/// Why this class exists: `XrplSeed`, `XrplSecp256k1`, `XrplEd25519`,
/// and `XrplClassicAddress` each solve one piece of the "seed to
/// usable account" pipeline in isolation, and were built and tested
/// that way on purpose (see `docs-sdk/`). `XrplWallet` is the layer
/// that assembles those pieces into what a real application actually
/// wants: generate or restore a wallet, and immediately have its key
/// pair and address available, without wiring the pipeline together
/// by hand every time.
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
///
/// See also: https://xrpl.org/docs/concepts/accounts
class XrplWallet {
  const XrplWallet._({
    required this.seed,
    required this.algorithm,
    required this.publicKeyBytes,
    required this.privateKeyBytes,
    required this.classicAddress,
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

  /// This wallet's classic address (for example
  /// `"rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN"`), derived once from
  /// [publicKeyBytes] via [XrplClassicAddress.deriveFrom] and cached
  /// here, since it never changes for a given wallet and deriving it
  /// again on every access would just repeat the same work.
  ///
  /// For an X-address (which additionally encodes the network and an
  /// optional destination tag), see `XrplXAddress.deriveFrom`,
  /// passing this wallet's [publicKeyBytes].
  final String classicAddress;

  /// Derives this wallet's X-address for the given [network],
  /// optionally embedding a destination [tag].
  ///
  /// Unlike [classicAddress], this is a method rather than a cached
  /// field: an X-address depends on parameters (which network, and
  /// which tag, if any) that can be different on every call, so
  /// there's nothing fixed to cache the way there is for the classic
  /// address.
  ///
  /// Throws an [XrplCryptoException] if [tag] is negative or exceeds
  /// the 32-bit unsigned maximum (via [XrplXAddress.deriveFrom]).
  ///
  /// Example:
  /// ```dart
  /// final address = wallet.xAddress(
  ///   network: XrplNetwork.mainnet,
  ///   tag: 12345,
  /// );
  /// ```
  String xAddress({required XrplNetwork network, int? tag}) {
    return XrplXAddress.deriveFrom(publicKeyBytes, network: network, tag: tag);
  }

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

    // Reject a seed that explicitly declares a different algorithm
    // than the one requested, instead of silently deriving the
    // "wrong" (but still valid-looking) key pair for it.
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
    // secp256k1 derivation is synchronous internally, but this method
    // stays async so callers get one consistent API regardless of
    // algorithm - see the class-level doc for why.
    if (algorithm == XrplKeyAlgorithm.secp256k1) {
      final keyPair = XrplSecp256k1.deriveKeyPair(seed.entropy);
      final publicKeyBytes = keyPair.compressedPublicKey;
      return XrplWallet._(
        seed: seed,
        algorithm: algorithm,
        publicKeyBytes: publicKeyBytes,
        privateKeyBytes: _bigIntToBytes(keyPair.privateKey, 32),
        // Derive the address once here, not lazily on first access,
        // so every XrplWallet instance is fully populated and
        // immutable from the moment it's constructed.
        classicAddress: XrplClassicAddress.deriveFrom(publicKeyBytes),
      );
    }

    final keyPair = await XrplEd25519.deriveKeyPair(seed.entropy);
    final publicKeyBytes = keyPair.prefixedPublicKey;
    return XrplWallet._(
      seed: seed,
      algorithm: algorithm,
      publicKeyBytes: publicKeyBytes,
      privateKeyBytes: keyPair.privateKey,
      classicAddress: XrplClassicAddress.deriveFrom(publicKeyBytes),
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
