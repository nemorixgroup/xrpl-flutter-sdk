import 'package:xrpl_flutter_sdk/src/connection/xrpl_path_find_amounts.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

/// Opens a `path_find` subscription on [connection]: the server returns
/// an initial snapshot of payment paths from [sourceAccount] to
/// [destinationAccount], then keeps sending updates as ledger conditions
/// change.
///
/// Why this exists: unlike `ripplePathFind` (one request, one response),
/// `path_find` is a streaming subscription. This helper sends the
/// `create` subcommand and returns the initial snapshot; the follow-up
/// updates arrive on [XrplConnection.pathFindEvents].
///
/// [destinationAmount] is an [XrplCurrencyAmount] or the literal `"-1"`
/// (the XRP form of "deliver as much as possible within [sendMax]"; for
/// an issued currency, use an [XrplCurrencyAmount.issued] with
/// `value: '-1'`). [sendMax] must be an [XrplCurrencyAmount]; `"-1"` is
/// rejected. [paths] optionally lists specific paths to monitor.
///
/// Only one `path_find` request can be active per connection. If one is
/// already open, the server would silently close it and replace it, so
/// this helper throws a [StateError] instead, unless [replaceExisting]
/// is `true`. Use [pathFindClose] to end a subscription explicitly.
///
/// Per the official specification, paths are not guaranteed to be
/// optimal and an untrusted server could return suboptimal ones; compare
/// results across independent servers when that matters. `path_find` is
/// also unnecessary for XRP-only payments, which transfer directly.
///
/// Throws an [ArgumentError] for invalid amounts, a [StateError] as
/// described above, and an `XrplConnectionException` (via
/// [XrplConnection.request]) if not connected, the request times out,
/// or the server returns an error.
///
/// Example:
/// ```dart
/// final snapshot = await pathFindCreate(
///   connection,
///   sourceAccount: wallet.classicAddress,
///   destinationAccount: destination,
///   destinationAmount: XrplCurrencyAmount.issued(
///     currency: 'USD',
///     issuer: 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
///     value: '0.001',
///   ),
/// );
/// connection.pathFindEvents.listen((update) {
///   print(update['alternatives']);
/// });
/// await pathFindClose(connection);
/// ```
///
/// See:
/// https://xrpl.org/docs/references/http-websocket-apis/public-api-methods/path-and-order-book-methods/path_find
Future<Map<String, dynamic>> pathFindCreate(
  XrplConnection connection, {
  required String sourceAccount,
  required String destinationAccount,
  required Object destinationAmount,
  Object? sendMax,
  List<XrplPath>? paths,
  bool replaceExisting = false,
}) async {
  // Build the request first, so invalid amounts fail before any state
  // check or network call.
  final params = <String, dynamic>{
    'subcommand': 'create',
    'source_account': sourceAccount,
    'destination_account': destinationAccount,
    'destination_amount': pathFindDestinationAmountJson(destinationAmount),
  };
  if (sendMax != null) params['send_max'] = pathFindSendMaxJson(sendMax);
  if (paths != null) {
    params['paths'] = paths.map((path) => path.toJson()).toList();
  }

  // Make the server's silent "new request replaces the old one"
  // behavior explicit: refuse unless the caller opted in.
  if (connection.hasActivePathFindSubscription && !replaceExisting) {
    throw StateError(
      'A path_find subscription is already open on this connection. '
      'Call pathFindClose first, or pass replaceExisting: true to let '
      'the server replace it.',
    );
  }

  final response = await connection.request('path_find', params);

  final result = response['result'];
  // Same defensive, intentionally-untested pattern as the queries.
  if (result is! Map<String, dynamic>) {
    throw const XrplConnectionException(
      'Unexpected path_find response shape: missing or invalid '
      '"result" field.',
    );
  }

  // Only mark the subscription open once the server confirmed it.
  connection.markPathFindSubscriptionActive(active: true);
  return result;
}

/// Returns an immediate snapshot of the open `path_find` subscription
/// on [connection], without changing it (the `status` subcommand).
///
/// Throws an `XrplConnectionException` (via [XrplConnection.request])
/// if not connected, the request times out, or no `path_find` request is
/// open (`noPathRequest`).
///
/// Example:
/// ```dart
/// final snapshot = await pathFindStatus(connection);
/// print(snapshot['alternatives']);
/// ```
///
/// See:
/// https://xrpl.org/docs/references/http-websocket-apis/public-api-methods/path-and-order-book-methods/path_find
Future<Map<String, dynamic>> pathFindStatus(XrplConnection connection) async {
  final response = await connection.request('path_find', {
    'subcommand': 'status',
  });

  final result = response['result'];
  if (result is! Map<String, dynamic>) {
    throw const XrplConnectionException(
      'Unexpected path_find status response shape: missing or invalid '
      '"result" field.',
    );
  }
  return result;
}

/// Closes the open `path_find` subscription on [connection] (the
/// `close` subcommand), so the server stops sending updates.
///
/// Throws an `XrplConnectionException` (via [XrplConnection.request])
/// if not connected, the request times out, or no `path_find` request is
/// open (`noPathRequest`).
///
/// Example:
/// ```dart
/// await pathFindClose(connection);
/// ```
///
/// See:
/// https://xrpl.org/docs/references/http-websocket-apis/public-api-methods/path-and-order-book-methods/path_find
Future<Map<String, dynamic>> pathFindClose(XrplConnection connection) async {
  final response = await connection.request('path_find', {
    'subcommand': 'close',
  });

  final result = response['result'];
  if (result is! Map<String, dynamic>) {
    throw const XrplConnectionException(
      'Unexpected path_find close response shape: missing or invalid '
      '"result" field.',
    );
  }

  // The server confirmed the close, so stop tracking the subscription.
  connection.markPathFindSubscriptionActive(active: false);
  return result;
}
