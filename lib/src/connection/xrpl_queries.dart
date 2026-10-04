import 'package:xrpl_flutter_sdk/src/connection/xrpl_path_find_amounts.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

/// Requests the connected server's own status: build version, sync
/// state, validated ledger range, and related operational info.
///
/// Why this exists: [XrplConnection.request] is deliberately generic
/// - it knows nothing about what `"server_info"` means or where the
/// useful data lives in the response envelope. This function is the
/// first of what will be a growing set of small, command-specific
/// helpers built on top of [XrplConnection.request], each knowing
/// just enough about one XRPL command to save callers from digging
/// through the raw response themselves.
///
/// [counters] requests additional low-level performance counters
/// from the server; per the official specification, most callers
/// don't need this and it defaults to `false`.
///
/// Throws an `XrplConnectionException` (via [XrplConnection.request])
/// if not connected, the request times out, or the server returns an
/// error.
///
/// Example:
/// ```dart
/// final info = await serverInfo(connection);
/// print(info['server_state']); // e.g. "full"
/// ```
///
/// See:
/// https://xrpl.org/docs/references/http-websocket-apis/public-api-methods/server-info-methods/server_info
Future<Map<String, dynamic>> serverInfo(
  XrplConnection connection, {
  bool counters = false,
}) async {
  final response = await connection.request('server_info', {
    'counters': counters,
  });

  // The useful data lives two levels deep in the response envelope
  // (result.info) - unwrap it here so callers don't have to know
  // that shape themselves. Verified with "is!" rather than an "as"
  // cast, consistent with the defensive pattern established in
  // XrplConnection._handleIncomingMessage during the Phase 3 audit:
  // a malformed response should raise a clear XrplConnectionException,
  // not an uncontrolled TypeError.
  final resultRaw = response['result'];
  // Note: this defensive check does not have a dedicated test. By
  // this point, connection.request() has already confirmed
  // status == "success", so a real XRPL server's response should
  // always have this shape per the official specification; the
  // same low-probability, not-worth-testing trade-off already
  // accepted for XrplConnection._handleIncomingMessage during this
  // audit.
  if (resultRaw is! Map<String, dynamic>) {
    throw const XrplConnectionException(
      'Unexpected server_info response shape: missing or invalid '
      '"result" field.',
    );
  }
  final infoRaw = resultRaw['info'];
  // Same trade-off as above.
  if (infoRaw is! Map<String, dynamic>) {
    throw const XrplConnectionException(
      'Unexpected server_info response shape: missing or invalid '
      '"result.info" field.',
    );
  }
  return infoRaw;
}

/// Requests account data (balance, sequence number, flags, and more)
/// for [account] from the connected server.
///
/// [account] is the only required field per the official
/// specification. The remaining parameters are all optional and
/// `null` by default - each is only included in the outgoing request
/// if explicitly provided, so the simplest call sends the minimal
/// request the official examples show (`{"account": "..."}`), not a
/// request padded with defaults nobody asked for:
/// - [ledgerHash]: a specific ledger version, by its hash
/// - [ledgerIndex]: a specific ledger version, by index or shortcut
///   (`"current"`, `"validated"`, `"closed"`)
/// - [queue]: whether to also return queued (not-yet-validated)
///   transactions for this account
/// - [signerLists]: whether to also return any multi-signing lists
///   configured for this account
///
/// Throws an `XrplConnectionException` (via [XrplConnection.request])
/// if not connected, the request times out, the account doesn't
/// exist (`actNotFound`), or another server-side error occurs.
///
/// Example:
/// ```dart
/// final accountData = await accountInfo(connection, wallet.classicAddress);
/// print(accountData['Balance']); // e.g. "999999999960"
/// ```
///
/// See:
/// https://xrpl.org/docs/references/http-websocket-apis/public-api-methods/account-methods/account_info
Future<Map<String, dynamic>> accountInfo(
  XrplConnection connection,
  String account, {
  String? ledgerHash,
  String? ledgerIndex,
  bool? queue,
  bool? signerLists,
}) async {
  // Build the request with only the fields that were actually
  // provided - the official examples never send every field at
  // once, and there's no reason to invent defaults for fields the
  // spec treats as genuinely optional.
  final params = <String, dynamic>{'account': account};
  if (ledgerHash != null) params['ledger_hash'] = ledgerHash;
  if (ledgerIndex != null) params['ledger_index'] = ledgerIndex;
  if (queue != null) params['queue'] = queue;
  if (signerLists != null) params['signer_lists'] = signerLists;

  final response = await connection.request('account_info', params);

  // Same defensive "is!" pattern as serverInfo above, instead of an
  // unchecked "as" cast.
  final resultRaw = response['result'];
  // Same untested-by-design trade-off as serverInfo above.
  if (resultRaw is! Map<String, dynamic>) {
    throw const XrplConnectionException(
      'Unexpected account_info response shape: missing or invalid '
      '"result" field.',
    );
  }
  final accountDataRaw = resultRaw['account_data'];
  // Same trade-off as above.
  if (accountDataRaw is! Map<String, dynamic>) {
    throw const XrplConnectionException(
      'Unexpected account_info response shape: missing or invalid '
      '"result.account_data" field.',
    );
  }
  return accountDataRaw;
}

/// Requests the network's current transaction cost information:
/// several already-calculated fee levels, and the current ledger
/// index.
///
/// Unlike [serverInfo] and [accountInfo], this returns the response's
/// full `result` object (not a further-nested field), since every
/// field in it - `drops`, `levels`, `ledger_current_index` - can be
/// directly useful, not just one nested sub-object.
///
/// Throws an `XrplConnectionException` (via [XrplConnection.request])
/// if not connected, the request times out, or the server returns an
/// error.
///
/// Example:
/// ```dart
/// final feeInfo = await fee(connection);
/// print(feeInfo['drops']['open_ledger_fee']); // e.g. "10"
/// print(feeInfo['ledger_current_index']); // e.g. 26575101
/// ```
///
/// See:
/// https://xrpl.org/docs/references/http-websocket-apis/public-api-methods/server-info-methods/fee
Future<Map<String, dynamic>> fee(XrplConnection connection) async {
  final response = await connection.request('fee');

  final resultRaw = response['result'];
  // Same defensive, intentionally-untested pattern as serverInfo and
  // accountInfo above (see docs-sdk/phase-3/closing-audit/ for why).
  if (resultRaw is! Map<String, dynamic>) {
    throw const XrplConnectionException(
      'Unexpected fee response shape: missing or invalid "result" field.',
    );
  }
  return resultRaw;
}

/// Requests information about a single transaction, by its
/// identifying [transactionHash].
///
/// The response includes a `validated` field: `false` (or absent)
/// means the result is still provisional, `true` means it's final -
/// see `docs-sdk/phase-4/submission/` for how `submitAndWait` uses
/// this to know when to stop polling.
///
/// Throws an `XrplConnectionException` (via [XrplConnection.request])
/// if not connected, the request times out, or - notably - if the
/// transaction hasn't been seen by this server yet (`txnNotFound`,
/// which is an expected, normal outcome while waiting for a recently
/// submitted transaction to propagate, not necessarily a real error).
///
/// Example:
/// ```dart
/// final result = await tx(connection, transactionHash);
/// print(result['validated']); // true, once final
/// ```
///
/// See:
/// https://xrpl.org/docs/references/http-websocket-apis/public-api-methods/transaction-methods/tx
Future<Map<String, dynamic>> tx(
  XrplConnection connection,
  String transactionHash,
) async {
  final response = await connection.request('tx', {
    'transaction': transactionHash,
  });

  final result = response['result'];
  // Same defensive, intentionally-untested pattern as serverInfo,
  // accountInfo, and fee above (see docs-sdk/phase-3/closing-audit/
  // for why).
  if (result is! Map<String, dynamic>) {
    throw const XrplConnectionException(
      'Unexpected tx response shape: missing or invalid "result" field.',
    );
  }
  return result;
}

/// Submits a signed transaction ([txBlob], as hex) to the network.
///
/// This only reports a *preliminary* result (`engine_result`, for
/// example `"tesSUCCESS"`) - it does not mean the transaction is
/// permanently part of the ledger yet. See `submitAndWait` for
/// waiting until the result is final.
///
/// If [failHard] is `true`, the server will not retry or relay the
/// transaction if it fails locally; defaults to `false`, matching the
/// official default.
///
/// Throws an `XrplConnectionException` (via [XrplConnection.request])
/// if not connected or the request times out.
///
/// Example:
/// ```dart
/// final result = await submit(connection, txBlobHex);
/// print(result['engine_result']); // e.g. "tesSUCCESS"
/// ```
///
/// See:
/// https://xrpl.org/docs/references/http-websocket-apis/public-api-methods/transaction-methods/submit
Future<Map<String, dynamic>> submit(
  XrplConnection connection,
  String txBlob, {
  bool failHard = false,
}) async {
  final response = await connection.request('submit', {
    'tx_blob': txBlob,
    'fail_hard': failHard,
  });

  final result = response['result'];
  if (result is! Map<String, dynamic>) {
    throw const XrplConnectionException(
      'Unexpected submit response shape: missing or invalid "result" field.',
    );
  }
  return result;
}

/// Requests a one-time snapshot of possible payment paths from
/// [sourceAccount] to [destinationAccount], for use in a cross-currency
/// `Payment` transaction's `Paths` field.
///
/// [destinationAmount] is either an [XrplCurrencyAmount] (the amount the
/// recipient should receive) or the literal string `"-1"`. Per the
/// official specification, `-1` asks for a path that delivers as much as
/// possible while spending no more than [sendMax] (if provided). The
/// literal `"-1"` is the XRP form of that request; for an issued
/// currency, use an [XrplCurrencyAmount.issued] with `value: '-1'`.
///
/// [sendMax] (the most the sender is willing to spend) must be an
/// [XrplCurrencyAmount] - unlike [destinationAmount], it does not accept
/// the `"-1"` literal, since the official specification only defines
/// that shortcut for `destination_amount`. Passing `"-1"` (or anything
/// else that isn't an [XrplCurrencyAmount]) throws an [ArgumentError].
///
/// [sourceCurrencies] (at most 18 entries) and [sendMax] are mutually
/// exclusive per the official specification: providing both throws an
/// [ArgumentError], same as [sourceCurrencies] exceeding 18 entries.
///
/// Per the official specification, the returned paths are not guaranteed
/// to be optimal, and a malicious or overloaded server could return
/// suboptimal paths; compare results across multiple independent servers
/// for anything where that matters. For continuous updates as ledger
/// conditions change, use `path_find` instead (see [pathFindCreate]).
///
/// Throws an `XrplConnectionException` (via [XrplConnection.request])
/// if not connected, the request times out, or the server returns an
/// error (for example `srcActMalformed`, `dstActMalformed`).
///
/// Example:
/// ```dart
/// final result = await ripplePathFind(
///   connection,
///   sourceAccount: wallet.classicAddress,
///   destinationAccount: destination,
///   destinationAmount: XrplCurrencyAmount.issued(
///     currency: 'USD',
///     issuer: 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
///     value: '0.001',
///   ),
/// );
/// print(result['alternatives']); // possible paths, or [] if none found
/// ```
///
/// See:
/// https://xrpl.org/docs/references/http-websocket-apis/public-api-methods/path-and-order-book-methods/ripple_path_find
Future<Map<String, dynamic>> ripplePathFind(
  XrplConnection connection, {
  required String sourceAccount,
  required String destinationAccount,
  required Object destinationAmount,
  List<XrplSourceCurrency>? sourceCurrencies,
  Object? sendMax,
  String? ledgerHash,
  String? ledgerIndex,
}) async {
  if (sourceCurrencies != null && sendMax != null) {
    throw ArgumentError(
      'sourceCurrencies and sendMax are mutually exclusive per the '
      'official specification; provide at most one.',
    );
  }
  if (sourceCurrencies != null && sourceCurrencies.length > 18) {
    throw ArgumentError(
      'sourceCurrencies accepts at most 18 entries per the official '
      'specification, got ${sourceCurrencies.length}.',
    );
  }

  // Build the request with only the fields that were actually
  // provided, matching the convention already used by accountInfo.
  final params = <String, dynamic>{
    'source_account': sourceAccount,
    'destination_account': destinationAccount,
    'destination_amount': pathFindDestinationAmountJson(destinationAmount),
  };
  if (sourceCurrencies != null) {
    params['source_currencies'] =
        sourceCurrencies.map((entry) => entry.toJson()).toList();
  }
  if (sendMax != null) params['send_max'] = pathFindSendMaxJson(sendMax);
  if (ledgerHash != null) params['ledger_hash'] = ledgerHash;
  if (ledgerIndex != null) params['ledger_index'] = ledgerIndex;

  final response = await connection.request('ripple_path_find', params);

  final result = response['result'];
  // Same defensive, intentionally-untested pattern as serverInfo,
  // accountInfo, fee, tx, and submit above.
  if (result is! Map<String, dynamic>) {
    throw const XrplConnectionException(
      'Unexpected ripple_path_find response shape: missing or invalid '
      '"result" field.',
    );
  }
  return result;
}
