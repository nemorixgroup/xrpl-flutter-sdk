import 'dart:typed_data';

import 'package:xrpl_flutter_sdk/src/codec/xrpl_base58.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_entropy.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_key_algorithm.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';

/// An XRPL family seed: the human-shareable, base58-encoded string a
/// user saves to recreate their key pair and address later.
///
/// XRPL uses two seed prefixes, per the official `ripple-address-codec`
/// reference implementation:
/// - `0x21` (one byte): the generic/classic prefix (`FAMILY_SEED`). A
///   seed with this prefix does **not** declare which signing
///   algorithm it is for; different tools may assume different
///   defaults. [declaredAlgorithm] is `null` for these seeds.
/// - `0x01 0xE1 0x4B` (three bytes, `ED25519_SEED`; the seed then
///   starts with `sEd...`): the Ed25519-specific prefix. A seed with
///   this prefix explicitly declares itself as Ed25519.
///
/// This class only encodes/decodes the seed string itself. It does
/// **not** derive key pairs - that happens in `0.0.4-dev`, where the
/// signing algorithm is always an explicit, required parameter,
/// never inferred silently, even when [declaredAlgorithm] is known.
class XrplSeed {
  /// Creates a seed wrapping existing [entropy].
  ///
  /// [declaredAlgorithm] should only be set to [XrplKeyAlgorithm.ed25519]
  /// when the seed will use (or was decoded from) the `sEd...` prefix.
  /// Leave it `null` for the generic `0x21` prefix.
  const XrplSeed(this.entropy, {this.declaredAlgorithm});

  /// Generates a new random seed for the given [algorithm].
  ///
  /// When [algorithm] is [XrplKeyAlgorithm.ed25519], the resulting
  /// seed uses the `sEd...` prefix, so any tool reading it later
  /// knows unambiguously which algorithm to use. When [algorithm] is
  /// [XrplKeyAlgorithm.secp256k1], the generic `0x21` prefix is used,
  /// since XRPL has no dedicated secp256k1 prefix.
  ///
  /// Example:
  /// ```dart
  /// final seed = XrplSeed.generate(algorithm: XrplKeyAlgorithm.ed25519);
  /// ```
  factory XrplSeed.generate({required XrplKeyAlgorithm algorithm}) {
    return XrplSeed(
      XrplEntropy.generate(),
      declaredAlgorithm:
          algorithm == XrplKeyAlgorithm.ed25519 ? algorithm : null,
    );
  }

  /// Decodes an XRPL seed [value] (for example `"snoPBrXtMe..."` or
  /// `"sEdTNFV69..."`), recognizing both the generic and the
  /// Ed25519-specific prefix, and verifying its checksum.
  ///
  /// Throws an [XrplCryptoException] if the checksum is invalid (via
  /// [XrplBase58.decodeWithChecksum]) or if the decoded data does not
  /// match the length of either known prefix.
  ///
  /// Example:
  /// ```dart
  /// final seed = XrplSeed.fromBase58('sEdTNFV69uSpcHpCppa6VzMvmC68CVY');
  /// print(seed.declaredAlgorithm); // XrplKeyAlgorithm.ed25519
  /// ```
  factory XrplSeed.fromBase58(String value) {
    final decoded = XrplBase58.decodeWithChecksum(value);

    if (decoded.length == _classicPrefix.length + XrplEntropy.lengthInBytes &&
        decoded[0] == _classicPrefix[0]) {
      return XrplSeed(
        XrplEntropy.fromBytes(decoded.sublist(_classicPrefix.length)),
      );
    }

    if (decoded.length == _ed25519Prefix.length + XrplEntropy.lengthInBytes &&
        decoded[0] == _ed25519Prefix[0] &&
        decoded[1] == _ed25519Prefix[1] &&
        decoded[2] == _ed25519Prefix[2]) {
      return XrplSeed(
        XrplEntropy.fromBytes(decoded.sublist(_ed25519Prefix.length)),
        declaredAlgorithm: XrplKeyAlgorithm.ed25519,
      );
    }

    throw const XrplCryptoException(
      'Unrecognized XRPL seed: prefix does not match the classic (0x21) '
      'or Ed25519 (sEd, 0x01 0xE1 0x4B) format',
    );
  }

  static const List<int> _classicPrefix = [0x21];
  static const List<int> _ed25519Prefix = [0x01, 0xE1, 0x4B];

  /// The underlying 16 bytes of entropy this seed was built from.
  final XrplEntropy entropy;

  /// The algorithm this seed's prefix explicitly declares, if any.
  ///
  /// `null` means the seed uses the generic `0x21` prefix and does
  /// not declare an algorithm; [XrplKeyAlgorithm.ed25519] means it
  /// uses the `sEd...` prefix. There is no equivalent explicit prefix
  /// for secp256k1 in the XRPL specification.
  final XrplKeyAlgorithm? declaredAlgorithm;

  /// Encodes this seed back into its base58 string form (for example
  /// `"snoPBrXtMe..."` or `"sEdTNFV69..."`), using whichever prefix
  /// matches [declaredAlgorithm].
  ///
  /// Example:
  /// ```dart
  /// final value = seed.toBase58();
  /// ```
  String toBase58() {
    final prefix = declaredAlgorithm == XrplKeyAlgorithm.ed25519
        ? _ed25519Prefix
        : _classicPrefix;
    final prefixed = Uint8List.fromList([...prefix, ...entropy.bytes]);
    return XrplBase58.encodeWithChecksum(prefixed);
  }
}
