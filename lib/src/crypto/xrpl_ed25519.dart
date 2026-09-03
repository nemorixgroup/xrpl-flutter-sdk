import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'package:xrpl_flutter_sdk/src/crypto/xrpl_entropy.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_hash.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_secp256k1.dart';

/// A raw Ed25519 key pair for the XRP Ledger.
class XrplEd25519KeyPair {
  /// Creates a key pair from an already-derived [privateKey] (the
  /// SHA-512Half of the seed's entropy) and its corresponding
  /// [publicKey].
  const XrplEd25519KeyPair({
    required this.privateKey,
    required this.publicKey,
  });

  /// The 32-byte private key: the SHA-512Half of the seed's entropy,
  /// used directly as a standard Ed25519 (RFC 8032) seed.
  final Uint8List privateKey;

  /// The raw 32-byte Ed25519 public key, without the `0xED` prefix.
  final Uint8List publicKey;

  /// The public key prefixed with `0xED` (33 bytes total), the form
  /// XRPL uses everywhere an Ed25519 public key is serialized, so
  /// that both secp256k1 (33-byte compressed) and Ed25519 public keys
  /// are always the same length.
  Uint8List get prefixedPublicKey => Uint8List.fromList([0xED, ...publicKey]);
}

/// Ed25519 key derivation for the XRP Ledger.
///
/// Much simpler than [XrplSecp256k1]: there is no root/intermediate
/// split, and (per the official specification) every 32-byte number
/// is technically a valid Ed25519 secret key, so there is no
/// validity-check retry loop either.
///
/// See: https://xrpl.org/docs/concepts/accounts/cryptographic-keys#ed25519-key-derivation
///
/// Uses `package:cryptography` (an actively maintained library) for
/// the actual curve operations rather than a synchronous but
/// long-unmaintained alternative - correctness and maintenance matter
/// more here than API symmetry with [XrplSecp256k1]. This makes
/// [deriveKeyPair] asynchronous, unlike secp256k1's derivation
/// methods; `XrplWallet` exposes a single, uniformly asynchronous public
/// API to hide this difference from SDK users.
class XrplEd25519 {
  const XrplEd25519._();

  static final Ed25519 _algorithm = Ed25519();

  /// Derives the Ed25519 key pair from [entropy] (the seed's 16 bytes).
  ///
  /// Per the official algorithm:
  /// 1. Calculate the SHA-512Half of the entropy - the result is used
  ///    directly as the 32-byte secret key.
  /// 2. Use standard Ed25519 (RFC 8032) public key derivation on that
  ///    secret key to derive the 32-byte public key.
  ///
  /// Example:
  /// ```dart
  /// final keyPair = await XrplEd25519.deriveKeyPair(entropy);
  /// print(keyPair.prefixedPublicKey.length); // 33
  /// ```
  static Future<XrplEd25519KeyPair> deriveKeyPair(XrplEntropy entropy) async {
    final secretKeyBytes = XrplHash.sha512Half(entropy.bytes);

    final keyPair = await _algorithm.newKeyPairFromSeed(secretKeyBytes);
    final extractedPublicKey = await keyPair.extractPublicKey();

    return XrplEd25519KeyPair(
      privateKey: secretKeyBytes,
      publicKey: Uint8List.fromList(extractedPublicKey.bytes),
    );
  }

  /// Signs [messageHash] with [privateKey] (the 32-byte secret key
  /// from a derived key pair), producing a 64-byte raw Ed25519
  /// signature.
  ///
  /// Unlike `secp256k1` signatures, no canonicalization is needed
  /// here: per the official specification, "All valid Ed25519
  /// signatures are fully canonical," so Ed25519 was never vulnerable
  /// to the transaction malleability problem `secp256k1` signatures
  /// require explicit handling for.
  ///
  /// Per XRPL's signing process, [messageHash] is expected to already
  /// be the `SHA-512Half` of the prefixed, serialized transaction
  /// (the same hash `secp256k1` signing uses) - not the raw
  /// transaction bytes. `package:cryptography`'s `Ed25519.sign` still
  /// performs its own standard Ed25519 hashing internally on whatever
  /// bytes it's given, exactly as it would for any other message;
  /// XRPL's specific choice is what that "message" happens to be.
  ///
  /// See: https://xrpl.org/docs/references/protocol/binary-format
  static Future<Uint8List> sign(
    Uint8List messageHash,
    Uint8List privateKey,
  ) async {
    final keyPair = await _algorithm.newKeyPairFromSeed(privateKey);
    final signature = await _algorithm.sign(messageHash, keyPair: keyPair);
    return Uint8List.fromList(signature.bytes);
  }
}
