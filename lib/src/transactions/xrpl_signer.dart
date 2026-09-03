import 'dart:typed_data';

import 'package:xrpl_flutter_sdk/src/crypto/xrpl_ed25519.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_hash.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_key_algorithm.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_secp256k1.dart';
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
/// and `TxnSignature` added - ready to be re-serialized and submitted
/// in `0.3.3-dev`.
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
/// 3. Prepend the single-signing prefix (`0x53545800`) and hash with
///    `SHA-512Half` - the same process for both signing algorithms
///    the XRP Ledger supports.
/// 4. Sign that hash with [wallet]'s private key - `secp256k1`
///    (DER-encoded, fully canonical) or Ed25519 (raw 64 bytes,
///    always canonical), depending on `wallet.algorithm`.
/// 5. Add `TxnSignature` (the signature, as uppercase hex) to the map.
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
  final withPublicKey = <String, dynamic>{
    ...transactionJson,
    'SigningPubKey': _bytesToHex(wallet.publicKeyBytes),
  };

  final serialized = XrplTransactionSerializer.serialize(withPublicKey);
  final prefixed = Uint8List.fromList([
    ..._singleSigningPrefix,
    ...serialized,
  ]);
  final messageHash = XrplHash.sha512Half(prefixed);

  final Uint8List signatureBytes;
  if (wallet.algorithm == XrplKeyAlgorithm.secp256k1) {
    final privateKeyInt = _bytesToBigInt(wallet.privateKeyBytes);
    signatureBytes = XrplSecp256k1.sign(messageHash, privateKeyInt);
  } else {
    signatureBytes = await XrplEd25519.sign(
      messageHash,
      wallet.privateKeyBytes,
    );
  }

  return <String, dynamic>{
    ...withPublicKey,
    'TxnSignature': _bytesToHex(signatureBytes),
  };
}

String _bytesToHex(Uint8List bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString().toUpperCase();
}

BigInt _bytesToBigInt(Uint8List bytes) {
  var result = BigInt.zero;
  for (final byte in bytes) {
    result = (result << 8) | BigInt.from(byte);
  }
  return result;
}
