import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_queries.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_connection_exception.dart';
import 'package:xrpl_flutter_sdk/src/transactions/binary/xrpl_transaction_serializer.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_transaction_hash.dart';

/// Submits [signedTransactionJson] (the output of `sign()`) and waits
/// until its result is final, returning the final `tx` response.
///
/// Why this exists: `submit` alone only reports a *preliminary*
/// result - it does not mean the transaction is permanently part of
/// the ledger. This is not an official XRPL API method; it is a
/// convenience this SDK provides on top of `submit` and `tx`, the
/// same way `xrpl.js`'s `submitAndWait` is a client-side convenience,
/// not a raw protocol command.
///
/// Follows the official "Reliable Transaction Submission" pattern:
/// submit once, then poll `tx` by the transaction's hash until either
/// `"validated": true` appears (the result - success or failure - is
/// final), or the latest **validated** ledger passes
/// [signedTransactionJson]'s `LastLedgerSequence` without that
/// happening (the transaction was not included and can be considered
/// expired).
///
/// The expiry check specifically uses `serverInfo`'s
/// `validated_ledger.seq`, not `fee`'s `ledger_current_index` - the
/// latter is the ledger currently being built (in progress, not yet
/// validated), always at least one ahead of the latest validated
/// ledger. Comparing against it declared transactions expired one
/// ledger too early in practice, confirmed by a real transaction that
/// genuinely validated successfully but was reported as expired by
/// this function before this fix - see
/// `docs-sdk/phase-4/submission/` for the full investigation.
///
/// A `tx` lookup that returns `txnNotFound` is expected and normal
/// while waiting for a recently submitted transaction to propagate -
/// this is treated as "not yet found," not as a fatal error, and
/// polling continues. Any other error is rethrown immediately.
///
/// [pollInterval] controls how long to wait between `tx` lookups;
/// defaults to 1 second, a reasonable balance against XRPL's typical
/// ~3-5 second ledger close time.
///
/// Throws an [XrplConnectionException] if [signedTransactionJson] has
/// no `LastLedgerSequence` (needed to know when to stop waiting), if
/// the transaction's `LastLedgerSequence` is passed by the latest
/// validated ledger without the transaction being validated, or if
/// `submit`/`tx`/`serverInfo` themselves throw for any other reason.
///
/// Example:
/// ```dart
/// final filled = await autofill(connection, payment);
/// final signed = await sign(filled.toJson(), wallet);
/// final result = await submitAndWait(connection, signed);
/// print(result['meta']['TransactionResult']); // e.g. "tesSUCCESS"
/// ```
///
/// See: https://xrpl.org/docs/concepts/transactions/reliable-transaction-submission
Future<Map<String, dynamic>> submitAndWait(
  XrplConnection connection,
  Map<String, dynamic> signedTransactionJson, {
  Duration pollInterval = const Duration(seconds: 1),
}) async {
  final lastLedgerSequence =
      signedTransactionJson['LastLedgerSequence'] as int?;
  if (lastLedgerSequence == null) {
    throw const XrplConnectionException(
      'submitAndWait requires LastLedgerSequence to already be set '
      '(via autofill), so it can know when to stop waiting for a '
      'transaction that will never be included.',
    );
  }

  final serialized = XrplTransactionSerializer.serialize(
    signedTransactionJson,
  );
  final txBlob = _bytesToHex(serialized);
  final txHash = transactionHash(signedTransactionJson);

  await submit(connection, txBlob);

  while (true) {
    Map<String, dynamic>? result;
    try {
      result = await tx(connection, txHash);
    } on XrplConnectionException catch (error) {
      if (!error.message.contains('txnNotFound')) rethrow;
    }

    if (result != null && result['validated'] == true) {
      return result;
    }

    final info = await serverInfo(connection);
    final validatedLedger = info['validated_ledger'] as Map<String, dynamic>;
    final latestValidatedLedger = validatedLedger['seq'] as int;

    if (latestValidatedLedger > lastLedgerSequence) {
      throw XrplConnectionException(
        'Transaction $txHash was not validated before its '
        'LastLedgerSequence ($lastLedgerSequence) was passed by the '
        'latest validated ledger ($latestValidatedLedger) - it was '
        'likely not included in the ledger.',
      );
    }

    await Future<void>.delayed(pollInterval);
  }
}

String _bytesToHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString().toUpperCase();
}
