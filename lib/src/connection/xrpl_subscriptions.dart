import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';

/// Subscribes [connection] to the `ledger` stream, so new
/// `ledgerClosed` events start arriving on [XrplConnection.ledgerEvents].
///
/// Why this exists: [XrplConnection.request] alone is enough to send
/// the raw `subscribe` command, but a caller would still need to
/// remember the exact stream name (`"ledger"`, not `"ledgers"` or
/// `"ledger_stream"`) and that streams are passed as a list even for
/// one item. This is the same small-helper pattern already used for
/// `serverInfo`/`accountInfo`, applied to subscriptions.
///
/// This only starts the subscription - actually receiving events
/// means listening to [XrplConnection.ledgerEvents] separately.
///
/// Throws an `XrplConnectionException` (via [XrplConnection.request])
/// if not connected or the server returns an error.
///
/// Example:
/// ```dart
/// await subscribeToLedger(connection);
/// connection.ledgerEvents.listen((event) {
///   print('New ledger: ${event['ledger_index']}');
/// });
/// ```
///
/// See:
/// https://xrpl.org/docs/references/http-websocket-apis/public-api-methods/subscription-methods/subscribe
Future<void> subscribeToLedger(XrplConnection connection) async {
  await connection.request('subscribe', {
    'streams': ['ledger'],
  });
}

/// Unsubscribes [connection] from the `ledger` stream. See
/// [subscribeToLedger].
Future<void> unsubscribeFromLedger(XrplConnection connection) async {
  await connection.request('unsubscribe', {
    'streams': ['ledger'],
  });
}

/// Subscribes [connection] to the `transactions` stream, so new
/// `transaction` events (for validated transactions) start arriving
/// on [XrplConnection.transactionEvents].
///
/// Set [includeProposed] to also receive not-yet-validated
/// transactions (the `transactions_proposed` stream); both streams
/// deliver events with the same `"transaction"` type, so they arrive
/// on the same [XrplConnection.transactionEvents] regardless.
///
/// Throws an `XrplConnectionException` (via [XrplConnection.request])
/// if not connected or the server returns an error.
///
/// Example:
/// ```dart
/// await subscribeToTransactions(connection);
/// connection.transactionEvents.listen((event) {
///   print('Transaction: ${event['hash']}');
/// });
/// ```
///
/// See:
/// https://xrpl.org/docs/references/http-websocket-apis/public-api-methods/subscription-methods/subscribe
Future<void> subscribeToTransactions(
  XrplConnection connection, {
  bool includeProposed = false,
}) async {
  await connection.request('subscribe', {
    'streams': [
      'transactions',
      if (includeProposed) 'transactions_proposed',
    ],
  });
}

/// Unsubscribes [connection] from the `transactions` stream (and
/// `transactions_proposed`, if [includeProposed] is true). See
/// [subscribeToTransactions].
Future<void> unsubscribeFromTransactions(
  XrplConnection connection, {
  bool includeProposed = false,
}) async {
  await connection.request('unsubscribe', {
    'streams': [
      'transactions',
      if (includeProposed) 'transactions_proposed',
    ],
  });
}

/// Subscribes [connection] to the `validations` stream, so new
/// `validationReceived` events start arriving on
/// [XrplConnection.validationEvents].
///
/// Throws an `XrplConnectionException` (via [XrplConnection.request])
/// if not connected or the server returns an error.
///
/// See:
/// https://xrpl.org/docs/references/http-websocket-apis/public-api-methods/subscription-methods/subscribe
Future<void> subscribeToValidations(XrplConnection connection) async {
  await connection.request('subscribe', {
    'streams': ['validations'],
  });
}

/// Unsubscribes [connection] from the `validations` stream. See
/// [subscribeToValidations].
Future<void> unsubscribeFromValidations(XrplConnection connection) async {
  await connection.request('unsubscribe', {
    'streams': ['validations'],
  });
}

/// Subscribes [connection] to the `server` stream, so new
/// `serverStatus` events start arriving on
/// [XrplConnection.serverEvents].
///
/// Throws an `XrplConnectionException` (via [XrplConnection.request])
/// if not connected or the server returns an error.
///
/// See:
/// https://xrpl.org/docs/references/http-websocket-apis/public-api-methods/subscription-methods/subscribe
Future<void> subscribeToServer(XrplConnection connection) async {
  await connection.request('subscribe', {
    'streams': ['server'],
  });
}

/// Unsubscribes [connection] from the `server` stream. See
/// [subscribeToServer].
Future<void> unsubscribeFromServer(XrplConnection connection) async {
  await connection.request('unsubscribe', {
    'streams': ['server'],
  });
}
