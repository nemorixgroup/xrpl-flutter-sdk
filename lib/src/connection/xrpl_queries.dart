import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';

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
  // that shape themselves.
  final result = response['result'] as Map<String, dynamic>;
  return result['info'] as Map<String, dynamic>;
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

  final result = response['result'] as Map<String, dynamic>;
  return result['account_data'] as Map<String, dynamic>;
}
