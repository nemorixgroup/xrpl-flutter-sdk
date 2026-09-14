import 'dart:typed_data';

import 'package:xrpl_flutter_sdk/src/codec/xrpl_hex_codec.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_ed25519.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_hash.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_key_algorithm.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_secp256k1.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';
import 'package:xrpl_flutter_sdk/src/transactions/binary/xrpl_transaction_serializer.dart';
import 'package:xrpl_flutter_sdk/src/wallet/xrpl_wallet.dart';

/// The single-signing prefix XRPL prepends before hashing a
/// transaction for signing, per the official Binary Format
/// specification - distinct from the multi-signing prefix
/// (`0x534D5400`), which this SDK does not support yet.
const List<int> _singleSigningPrefix = [0x53, 0x54, 0x58, 0x00];

/// Signs [transactionJson] (the `toJson()` output of an
/// `XrplPayment`/`XrplTrustSet`, normally already filled in via
/// `autofill`) with [wallet], returning a new map with `SigningPubKey`
/// and `TxnSignature` added - ready to be re-serialized (via
/// `XrplTransactionSerializer`) and submitted (via `submit` or
/// `submitAndWait`).
///
/// Why this works on a plain map, not the transaction model classes:
/// same reasoning as `XrplTransactionSerializer` - `SigningPubKey`
/// and `TxnSignature` are added here rather than as fields on every
/// transaction model, keeping this logic generic across transaction
/// types.
///
/// The signing process, per the official specification:
/// 1. Add `SigningPubKey` (required before serializing for signing).
/// 2. Serialize to canonical binary format.
/// 3. Prepend the single-signing prefix (`0x53545800`).
/// 4. Sign that data with [wallet]'s private key - the two supported
///    algorithms differ here, confirmed by directly comparing against
///    `xrpl.js`'s own internal signing data (see
///    `docs-sdk/phase-4/submission/` for the full investigation):
///    - `secp256k1` (ECDSA) can only sign a fixed-size digest, so the
///      prefixed data is hashed with `SHA-512Half` first, then that
///      hash is signed (DER-encoded, fully canonical).
///    - `Ed25519` (EdDSA) signs messages of arbitrary length
///      directly - it performs its own internal `SHA-512` hashing as
///      part of the algorithm, so the prefixed data is signed as-is,
///      with no separate pre-hashing step.
/// 5. Add `TxnSignature` (the signature, as uppercase hex) to the map.
///
/// Throws an [XrplCryptoException] if [transactionJson] already has
/// an `Account` field that doesn't match [wallet]'s own address - a
/// mismatch that would otherwise go undetected here and only surface
/// later as a confusing rejection from the network, since a
/// transaction signed by the wrong wallet is still a mathematically
/// valid signature, just for an account other than the one intended.
///
/// Example:
/// ```dart
/// final ready = await autofill(connection, payment);
/// final signed = await sign(ready.toJson(), wallet);
/// print(signed['TxnSignature']);
/// ```
///
/// See:
/// https://xrpl.org/docs/references/protocol/binary-format
Future<Map<String, dynamic>> sign(
  Map<String, dynamic> transactionJson,
  XrplWallet wallet,
) async {
  final declaredAccount = transactionJson['Account'];
  if (declaredAccount != null && declaredAccount != wallet.classicAddress) {
    throw XrplCryptoException(
      "transactionJson's Account ($declaredAccount) does not match "
      "wallet's address (${wallet.classicAddress}) - refusing to sign "
      'a transaction for a different account than the wallet provided.',
    );
  }

  final withPublicKey = <String, dynamic>{
    ...transactionJson,
    'SigningPubKey': XrplHexCodec.bytesToHex(wallet.publicKeyBytes),
  };

  final serialized = XrplTransactionSerializer.serialize(withPublicKey);
  final prefixed = Uint8List.fromList([
    ..._singleSigningPrefix,
    ...serialized,
  ]);

  final Uint8List signatureBytes;
  if (wallet.algorithm == XrplKeyAlgorithm.secp256k1) {
    // secp256k1 (ECDSA) can only sign a fixed-size digest, so the
    // prefixed transaction bytes are hashed first.
    final messageHash = XrplHash.sha512Half(prefixed);
    final privateKeyInt = _bytesToBigInt(wallet.privateKeyBytes);
    signatureBytes = XrplSecp256k1.sign(messageHash, privateKeyInt);
  } else {
    // Ed25519 (EdDSA) signs messages of arbitrary length directly -
    // it performs its own internal SHA-512 hashing as part of the
    // algorithm. XRPL does NOT pre-hash with SHA-512Half for Ed25519,
    // unlike secp256k1 - confirmed by decoding xrpl.js's own
    // internal signing data and testing both hypotheses directly
    // against a real, independently-computed signature. See
    // docs-sdk/phase-4/submission/ for the full investigation.
    signatureBytes = await XrplEd25519.sign(
      prefixed,
      wallet.privateKeyBytes,
    );
  }

  return <String, dynamic>{
    ...withPublicKey,
    'TxnSignature': XrplHexCodec.bytesToHex(signatureBytes),
  };
}

BigInt _bytesToBigInt(Uint8List bytes) {
  var result = BigInt.zero;
  for (final byte in bytes) {
    result = (result << 8) | BigInt.from(byte);
  }
  return result;
}
