import 'package:xrpl_flutter_sdk/src/codec/xrpl_hex_codec.dart';
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
/// ~3-5 second ledger close time. Must be positive - a zero or
/// negative interval would poll the server in a tight, unthrottled
/// loop.
///
/// Throws an [XrplConnectionException] if [pollInterval] is not
/// positive, if [signedTransactionJson] has no `LastLedgerSequence`
/// (needed to know when to stop waiting) or has one with an
/// unexpected type, if the submitted transaction is rejected outright
/// by the server with a `tem*` (malformed) or `tef*` (failure) result
/// - these are definitive per the official specification and will
/// never be included in a ledger, so this fails immediately rather
/// than waiting out the full expiration window - if the transaction's
/// `LastLedgerSequence` is passed by the latest validated ledger
/// without the transaction being validated, if the server's response
/// for `validated_ledger` or its `seq` doesn't have the expected
/// shape, or if `submit`/`tx`/`serverInfo` themselves throw for any
/// other reason.
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
  if (pollInterval <= Duration.zero) {
    throw XrplConnectionException(
      'pollInterval must be positive, got $pollInterval',
    );
  }

  final lastLedgerSequenceRaw = signedTransactionJson['LastLedgerSequence'];
  if (lastLedgerSequenceRaw == null) {
    throw const XrplConnectionException(
      'submitAndWait requires LastLedgerSequence to already be set '
      '(via autofill), so it can know when to stop waiting for a '
      'transaction that will never be included.',
    );
  }
  if (lastLedgerSequenceRaw is! int) {
    throw XrplConnectionException(
      "signedTransactionJson's LastLedgerSequence must be an int, "
      'got ${lastLedgerSequenceRaw.runtimeType}',
    );
  }
  final lastLedgerSequence = lastLedgerSequenceRaw;

  final serialized = XrplTransactionSerializer.serialize(
    signedTransactionJson,
  );
  final txBlob = XrplHexCodec.bytesToHex(serialized);
  final txHash = transactionHash(signedTransactionJson);

  final submitResult = await submit(connection, txBlob);

  // "tem" (malformed) and "tef" (failure) results are definitive:
  // per the official specification, a transaction rejected with one
  // of these codes is never relayed or retried, and will never be
  // included in any ledger. Failing immediately here, instead of
  // entering the polling loop below, avoids waiting out the full
  // LastLedgerSequence window (tens of seconds to minutes) only to
  // report a generic "not validated" error that hides the real,
  // already-known reason. "tes" (preliminary success), "tec" (failed
  // but still claims the fee and is included in a ledger), and "ter"
  // (local error, may be retried by the server itself) are all left
  // to the normal polling below, since each of these can still result
  // in a transaction that is genuinely included and validated.
  final engineResult = submitResult['engine_result'] as String?;
  if (engineResult != null &&
      (engineResult.startsWith('tem') || engineResult.startsWith('tef'))) {
    final message =
        submitResult['engine_result_message'] as String? ?? engineResult;
    throw XrplConnectionException(
      'Transaction $txHash was rejected by the server and will never '
      'be included in a ledger ($engineResult: $message).',
    );
  }

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
    final validatedLedgerRaw = info['validated_ledger'];
    if (validatedLedgerRaw is! Map<String, dynamic>) {
      throw const XrplConnectionException(
        'Unexpected server_info response shape: missing or invalid '
        '"validated_ledger" field.',
      );
    }
    final latestValidatedLedgerRaw = validatedLedgerRaw['seq'];
    if (latestValidatedLedgerRaw is! int) {
      throw const XrplConnectionException(
        'Unexpected server_info response shape: missing or invalid '
        '"validated_ledger.seq" field.',
      );
    }

    if (latestValidatedLedgerRaw > lastLedgerSequence) {
      throw XrplConnectionException(
        'Transaction $txHash was not validated before its '
        'LastLedgerSequence ($lastLedgerSequence) was passed by the '
        'latest validated ledger ($latestValidatedLedgerRaw) - it was '
        'likely not included in the ledger.',
      );
    }

    await Future<void>.delayed(pollInterval);
  }
}
