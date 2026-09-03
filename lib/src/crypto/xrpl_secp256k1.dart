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

  /// Signs [messageHash] (expected to already be a hash, per XRPL's
  /// signing process - see `docs-sdk/phase-4/signing/`) with
  /// [privateKey], producing a DER-encoded, "fully canonical"
  /// signature as XRPL requires.
  ///
  /// "Fully canonical" means, per the official specification: proper
  /// DER encoding, non-negative R/S values smaller than the curve's
  /// group order, and - the part a generic ECDSA implementation does
  /// not guarantee on its own - the *smaller* of the two
  /// mathematically valid S values (`S` or `N - S`), normalized here
  /// if the raw signature comes back with the larger one.
  ///
  /// Uses RFC 6979 deterministic nonce generation (via pointycastle's
  /// `HMacDSAKCalculator`), so signing the same hash with the same
  /// key always produces the same signature - both a security
  /// best practice (avoids nonce-reuse risks from a weak random
  /// source) and something independently verifiable against another
  /// RFC 6979 implementation, which this SDK does before trusting it.
  ///
  /// See:
  /// https://xrpl.org/docs/concepts/transactions/finality-of-results/transaction-malleability
  static Uint8List sign(Uint8List messageHash, BigInt privateKey) {
    final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
    final privateKeyParam = ECPrivateKey(privateKey, _domainParams);
    signer.init(true, PrivateKeyParameter(privateKeyParam));

    var signature = signer.generateSignature(messageHash) as ECSignature;

    // Normalize to the smaller of S or N-S ("low-S"), the part of
    // "fully canonical" a generic ECDSA signer does not enforce on
    // its own.
    final halfOrder = _domainParams.n >> 1;
    if (signature.s > halfOrder) {
      signature = ECSignature(signature.r, _domainParams.n - signature.s);
    }

    return _derEncode(signature.r, signature.s);
  }

  static Uint8List _derEncode(BigInt r, BigInt s) {
    final rBytes = _derEncodeInteger(r);
    final sBytes = _derEncodeInteger(s);
    final sequenceContent = Uint8List.fromList([...rBytes, ...sBytes]);
    return Uint8List.fromList([
      0x30, // SEQUENCE tag
      sequenceContent.length,
      ...sequenceContent,
    ]);
  }

  static Uint8List _derEncodeInteger(BigInt value) {
    var bytes = _bigIntToMinimalBytes(value);
    // DER requires a leading 0x00 if the high bit is set, so the
    // integer is never misread as negative (DER integers are signed).
    if (bytes.isNotEmpty && (bytes[0] & 0x80) != 0) {
      bytes = Uint8List.fromList([0x00, ...bytes]);
    }
    return Uint8List.fromList([0x02, bytes.length, ...bytes]);
  }

  static Uint8List _bigIntToMinimalBytes(BigInt value) {
    if (value == BigInt.zero) return Uint8List.fromList([0]);
    var hex = value.toRadixString(16);
    if (hex.length.isOdd) hex = '0$hex';
    return _hexToBytes(hex);
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  /// Verifies that [derSignature] is a valid signature of
  /// [messageHash] by the holder of [publicKey].
  ///
  /// Accepts any DER-encoded signature that decodes to valid R/S
  /// values, not only ones this SDK's own [sign] produced - useful
  /// for confirming interoperability with signatures from other,
  /// independent implementations, not just testing round-trips
  /// against itself.
  static bool verify(
    Uint8List messageHash,
    Uint8List derSignature,
    ECPoint publicKey,
  ) {
    final signer = ECDSASigner(null, HMac(SHA256Digest(), 64))
      ..init(false, PublicKeyParameter(ECPublicKey(publicKey, _domainParams)));

    final (r, s) = _derDecode(derSignature);
    return signer.verifySignature(messageHash, ECSignature(r, s));
  }

  static (BigInt, BigInt) _derDecode(Uint8List der) {
    // der[0] = 0x30 (SEQUENCE), der[1] = total content length.
    var offset = 2;

    // der[offset] = 0x02 (INTEGER tag) for R.
    offset++;
    final rLength = der[offset];
    offset++;
    final r = _bytesToBigInt(der.sublist(offset, offset + rLength));
    offset += rLength;

    // der[offset] = 0x02 (INTEGER tag) for S.
    offset++;
    final sLength = der[offset];
    offset++;
    final s = _bytesToBigInt(der.sublist(offset, offset + sLength));

    return (r, s);
  }

  /// Decodes a 33-byte compressed public key (the format
  /// [XrplSecp256k1KeyPair.compressedPublicKey] produces) back into
  /// its curve point, the inverse of that compression.
  ///
  /// Throws an [XrplCryptoException] if [compressedPublicKey] is not
  /// exactly 33 bytes, or does not decode to a valid point on the
  /// secp256k1 curve.
  static ECPoint decodeCompressedPublicKey(Uint8List compressedPublicKey) {
    if (compressedPublicKey.length != 33) {
      throw XrplCryptoException(
        'compressedPublicKey must be exactly 33 bytes, got '
        '${compressedPublicKey.length}',
      );
    }

    final point = _domainParams.curve.decodePoint(compressedPublicKey);
    if (point == null) {
      throw const XrplCryptoException(
        'compressedPublicKey is not a valid point on the secp256k1 curve.',
      );
    }
    return point;
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
