import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'package:xrpl_flutter_sdk/src/crypto/xrpl_entropy.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_hash.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';

/// A raw secp256k1 key pair: a private key scalar and its
/// corresponding public key point on the curve.
///
/// This is an internal building block. [XrplSecp256k1] combines two
/// of these (a "root" and an "intermediate" pair) to produce the
/// final account key pair - see the module-level documentation in
/// `docs-sdk/phase-1/key-derivation/` for the full picture.
class XrplSecp256k1KeyPair {
  /// Creates a key pair from an already-derived [privateKey] scalar
  /// and its corresponding [publicKey] point.
  const XrplSecp256k1KeyPair({
    required this.privateKey,
    required this.publicKey,
  });

  /// The private key, as the raw scalar used in curve arithmetic.
  final BigInt privateKey;

  /// The public key, as a point on the secp256k1 curve.
  final ECPoint publicKey;

  /// The public key in its 33-byte compressed form: a one-byte prefix
  /// (`0x02` if the Y coordinate is even, `0x03` if odd) followed by
  /// the 32-byte X coordinate.
  Uint8List get compressedPublicKey => publicKey.getEncoded();
}

/// secp256k1 key derivation for the XRP Ledger.
///
/// XRPL's secp256k1 derivation is more involved than Ed25519's: not
/// every 32-byte number is a valid secp256k1 secret key, and the
/// account's final key pair is actually the sum of two separately
/// derived key pairs (a "root" pair and an "intermediate" pair) - a
/// leftover, still-required part of an unfinished "key family"
/// design in XRPL's reference implementation.
///
/// See: https://xrpl.org/docs/concepts/accounts/cryptographic-keys#secp256k1-key-derivation
class XrplSecp256k1 {
  const XrplSecp256k1._();

  static final ECDomainParameters _domainParams =
      ECDomainParameters('secp256k1');

  /// Derives the "root key pair" from [entropy] (the seed's 16 bytes).
  ///
  /// Per the official algorithm:
  /// 1. Concatenate the entropy with a 4-byte, big-endian "root
  ///    sequence" starting at 0.
  /// 2. Take the SHA-512Half of that concatenation as a candidate
  ///    private key.
  /// 3. If the candidate is zero, or is not smaller than the
  ///    secp256k1 group order, increment the sequence and retry.
  /// 4. Once valid, derive the public key point via standard ECDSA
  ///    public key derivation.
  ///
  /// This is also the key pair XRPL validators use directly (their
  /// public keys use the `0x1c` base58 prefix, distinct from account
  /// keys) - accounts go one step further, combining this with an
  /// "intermediate" key pair - see [deriveKeyPair].
  ///
  /// Example:
  /// ```dart
  /// final root = XrplSecp256k1.deriveRootKeyPair(entropy);
  /// print(root.compressedPublicKey.length); // 33
  /// ```
  static XrplSecp256k1KeyPair deriveRootKeyPair(XrplEntropy entropy) {
    return _deriveValidKeyPair(entropy.bytes);
  }

  /// Derives the "intermediate key pair" from a [rootPublicKey] (the
  /// 33-byte compressed public key from [deriveRootKeyPair]).
  ///
  /// Per the official algorithm:
  /// 1. Concatenate the compressed root public key, 4 zero bytes
  ///    (a "family number" field that XRPL's reference implementation
  ///    defines but never actually varies in practice), and a 4-byte,
  ///    big-endian "intermediate sequence" starting at 0.
  /// 2. Take the SHA-512Half of that concatenation as a candidate
  ///    private key, retrying with an incremented sequence if it
  ///    isn't a valid secp256k1 key - the same validity rule and
  ///    retry loop as [deriveRootKeyPair].
  /// 3. Once valid, derive the public key point the same way.
  ///
  /// This key pair is never used on its own - it's combined with the
  /// root key pair (via modular addition of the private keys, and
  /// elliptic-curve point addition of the public keys) to produce the
  /// account's actual master key pair - see [deriveKeyPair].
  ///
  /// Throws an [XrplCryptoException] if [rootPublicKey] is not
  /// exactly 33 bytes (the compressed public key length), since a
  /// key pair derived from the wrong input length would not match
  /// what any other XRPL tool would produce from the same seed.
  ///
  /// Example:
  /// ```dart
  /// final root = XrplSecp256k1.deriveRootKeyPair(entropy);
  /// final intermediate = XrplSecp256k1.deriveIntermediateKeyPair(
  ///   root.compressedPublicKey,
  /// );
  /// ```
  static XrplSecp256k1KeyPair deriveIntermediateKeyPair(
    Uint8List rootPublicKey,
  ) {
    const expectedLength = 33;
    if (rootPublicKey.length != expectedLength) {
      throw XrplCryptoException(
        'rootPublicKey must be exactly $expectedLength bytes '
        '(a compressed secp256k1 public key), got '
        '${rootPublicKey.length}',
      );
    }

    final familyNumber = Uint8List(4); // always zero, per the spec
    final baseInput = Uint8List.fromList([
      ...rootPublicKey,
      ...familyNumber,
    ]);
    return _deriveValidKeyPair(baseInput);
  }

  /// Derives the final, usable secp256k1 key pair from [entropy] -
  /// this is the method most code should call, since it runs the
  /// complete official algorithm end to end.
  ///
  /// Combines [deriveRootKeyPair] and [deriveIntermediateKeyPair]:
  /// - the master private key is the sum of both private keys,
  ///   modulo the secp256k1 group order
  /// - the master public key is the sum of both public key points,
  ///   using elliptic-curve point addition
  ///
  /// Example:
  /// ```dart
  /// final keyPair = XrplSecp256k1.deriveKeyPair(entropy);
  /// print(keyPair.compressedPublicKey.length); // 33
  /// ```
  static XrplSecp256k1KeyPair deriveKeyPair(XrplEntropy entropy) {
    final root = deriveRootKeyPair(entropy);
    final intermediate = deriveIntermediateKeyPair(root.compressedPublicKey);

    final masterPrivateKey =
        (root.privateKey + intermediate.privateKey) % _domainParams.n;
    final masterPublicKey = root.publicKey + intermediate.publicKey;

    return XrplSecp256k1KeyPair(
      privateKey: masterPrivateKey,
      publicKey: masterPublicKey!,
    );
  }

  /// Shared "hash, validate, retry" loop used for both the root and
  /// (later) the intermediate key pair derivation steps - the two
  /// steps differ only in what bytes are hashed, not in this logic.
  static XrplSecp256k1KeyPair _deriveValidKeyPair(Uint8List baseInput) {
    var sequence = 0;
    while (true) {
      final sequenceBytes = Uint8List(4)
        ..buffer.asByteData().setUint32(0, sequence);
      final candidateInput = Uint8List.fromList([
        ...baseInput,
        ...sequenceBytes,
      ]);
      final candidateBytes = XrplHash.sha512Half(candidateInput);
      final candidate = _bytesToBigInt(candidateBytes);

      if (_isValidPrivateKey(candidate)) {
        final publicPoint = _domainParams.G * candidate;
        return XrplSecp256k1KeyPair(
          privateKey: candidate,
          publicKey: publicPoint!,
        );
      }

      sequence++;
    }
  }

  static bool _isValidPrivateKey(BigInt candidate) {
    return candidate > BigInt.zero && candidate < _domainParams.n;
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }
}
