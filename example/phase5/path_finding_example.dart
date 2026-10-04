// Phase 5 - 0.4.2-dev: Path Finding (ripple_path_find & path_find)
//
// Demonstrates XRPL's two path-finding commands, used to discover
// how a cross-currency Payment could be routed. ripple_path_find is a
// single request/response snapshot. path_find is a streaming
// subscription: the server returns an initial snapshot, then keeps
// sending updates as ledger conditions change.
//
// Both examples ask for a currency ("TST") issued by the destination
// account itself. This keeps them self-contained, with no TrustSet or
// extra setup, but it also means no real path exists between the two
// unrelated wallets, so the server correctly returns no alternatives.
// What these examples show is the request/response flow and the
// subscription lifecycle, not path quality.
//
// Full technical decisions:
// https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-5

import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

Future<void> ripplePathFindExample() async {
  final connection = XrplConnection(XrplEndpoint.testnet);
  await connection.connect();

  // source_account must actually exist on the ledger, otherwise the
  // server rejects the request with srcActNotFound, so both wallets
  // are funded first.
  final source = await fundTestWallet(connection);
  final destination = await fundTestWallet(connection);
  print('Source: ${source.classicAddress}');
  print('Destination: ${destination.classicAddress}');

  final result = await ripplePathFind(
    connection,
    sourceAccount: source.classicAddress,
    destinationAccount: destination.classicAddress,
    destinationAmount: XrplCurrencyAmount.issued(
      currency: 'TST',
      issuer: destination.classicAddress,
      value: '1',
    ),
  );

  // "alternatives" is empty when no route exists, which is the expected
  // outcome here (see the note at the top of this file).
  final alternatives = result['alternatives'] as List<dynamic>;
  print('Alternatives found: ${alternatives.length}');

  await connection.disconnect();
}

Future<void> pathFindExample() async {
  final connection = XrplConnection(XrplEndpoint.testnet);
  await connection.connect();

  final source = await fundTestWallet(connection);
  final destination = await fundTestWallet(connection);

  // Start waiting for the first streaming update before opening the
  // subscription, so an update arriving right after the initial
  // snapshot cannot be missed.
  final firstUpdate = connection.pathFindEvents.first.timeout(
    const Duration(seconds: 45),
  );

  // "create" opens the subscription and returns the initial snapshot.
  // Only one path_find request can be active per connection, so a
  // second create without replaceExisting: true would throw a
  // StateError instead of silently replacing this one.
  final snapshot = await pathFindCreate(
    connection,
    sourceAccount: source.classicAddress,
    destinationAccount: destination.classicAddress,
    destinationAmount: XrplCurrencyAmount.issued(
      currency: 'TST',
      issuer: destination.classicAddress,
      value: '1',
    ),
  );
  final initial = snapshot['alternatives'] as List<dynamic>;
  print('Initial alternatives: ${initial.length}');
  print('Subscription open: ${connection.hasActivePathFindSubscription}');

  // Follow-up updates arrive on pathFindEvents as ledgers close.
  final update = await firstUpdate;
  print('First streaming update type: ${update['type']}');

  // "status" returns a snapshot without changing the subscription.
  final status = await pathFindStatus(connection);
  final current = status['alternatives'] as List<dynamic>;
  print('Alternatives from status: ${current.length}');

  // "close" ends the subscription so the server stops sending updates.
  final closed = await pathFindClose(connection);
  print('Closed: ${closed['closed']}');
  print('Subscription open: ${connection.hasActivePathFindSubscription}');

  await connection.disconnect();
}
