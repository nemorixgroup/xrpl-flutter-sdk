import 'dart:typed_data';

import 'package:xrpl_flutter_sdk/src/crypto/xrpl_hash.dart';
import 'package:xrpl_flutter_sdk/src/transactions/binary/xrpl_transaction_serializer.dart';

/// The prefix used specifically for computing a *signed* transaction's
/// identifying hash - distinct from the single-signing prefix
/// (`0x53545800`) used when computing the hash that gets signed in
/// the first place.
///
/// Confirmed against two independent sources: the official
/// `xrpl-dev-portal` hash-prefix table, and a real, maintained
/// third-party Rust implementation's source constants
/// (`HASH_PREFIX_SIGNED_TRANSACTION`).
const List<int> _signedTransactionPrefix = [0x54, 0x58, 0x4E, 0x00];

/// Computes a signed transaction's identifying hash (the value used
/// to look it up later via the `tx` command, and what most block
/// explorers display as the transaction's ID).
///
/// [signedTransactionJson] must already include `TxnSignature` (the
/// output of `sign()`) - this is a genuinely different hash from the
/// one computed during signing, using a different prefix over the
/// same field's *final*, signed serialization.
///
/// Example:
/// ```dart
/// final signed = await sign(filled.toJson(), wallet);
/// final hash = transactionHash(signed);
/// ```
String transactionHash(Map<String, dynamic> signedTransactionJson) {
  final serialized = XrplTransactionSerializer.serialize(
    signedTransactionJson,
  );
  final prefixed = Uint8List.fromList([
    ..._signedTransactionPrefix,
    ...serialized,
  ]);
  final hash = XrplHash.sha512Half(prefixed);

  final buffer = StringBuffer();
  for (final byte in hash) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString().toUpperCase();
}
