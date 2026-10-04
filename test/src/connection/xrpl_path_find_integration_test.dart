@Timeout(Duration(minutes: 2))
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

// Integration test: calls pathFindCreate(), pathFindStatus(), and
// pathFindClose() against the real public Testnet server. Kept in
// test/src/ alongside the other network-dependent tests, apart from the
// pure unit tests in test/connection/xrpl_path_find_test.dart.
void main() {
  group('path_find against the real public Testnet server', () {
    // Both accounts are only read from (never modified) by these tests,
    // so they are funded once for the whole group instead of once per
    // test, to avoid hammering the faucet.
    late String sourceAddress;
    late String destinationAddress;

    setUpAll(() async {
      final fundingConnection = XrplConnection(XrplEndpoint.testnet);
      await fundingConnection.connect();

      // source_account must actually exist on the ledger, or the server
      // rejects the request with srcActNotFound (same finding as the
      // ripplePathFind integration test).
      sourceAddress = (await fundTestWallet(fundingConnection)).classicAddress;
      destinationAddress =
          (await fundTestWallet(fundingConnection)).classicAddress;

      await fundingConnection.disconnect();
    });

    // A currency only the destination issues, so no real path exists
    // between these two unrelated accounts. These tests check the
    // subscription lifecycle and message routing, not path quality.
    Future<Map<String, dynamic>> openSubscription(
      XrplConnection connection, {
      bool replaceExisting = false,
    }) {
      return pathFindCreate(
        connection,
        sourceAccount: sourceAddress,
        destinationAccount: destinationAddress,
        destinationAmount: XrplCurrencyAmount.issued(
          currency: 'TST',
          issuer: destinationAddress,
          value: '1',
        ),
        replaceExisting: replaceExisting,
      );
    }

    test(
      'create, status and close follow the full subscription lifecycle',
      () async {
        final connection = XrplConnection(XrplEndpoint.testnet);
        await connection.connect();
        addTearDown(connection.disconnect);

        final created = await openSubscription(connection);

        expect(created['destination_account'], destinationAddress);
        expect(created['alternatives'], isA<List<dynamic>>());
        expect(connection.hasActivePathFindSubscription, isTrue);

        final status = await pathFindStatus(connection);

        expect(status['alternatives'], isA<List<dynamic>>());
        // status must not change the subscription.
        expect(connection.hasActivePathFindSubscription, isTrue);

        final closed = await pathFindClose(connection);

        expect(closed['closed'], isTrue);
        expect(connection.hasActivePathFindSubscription, isFalse);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'a second create throws StateError unless replaceExisting is true',
      () async {
        final connection = XrplConnection(XrplEndpoint.testnet);
        await connection.connect();
        addTearDown(connection.disconnect);

        await openSubscription(connection);

        await expectLater(openSubscription(connection), throwsStateError);

        // With the explicit opt-in, the server replaces the first request.
        final replaced = await openSubscription(
          connection,
          replaceExisting: true,
        );

        expect(replaced['destination_account'], destinationAddress);
        expect(connection.hasActivePathFindSubscription, isTrue);

        await pathFindClose(connection);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'status and close fail with noPathRequest when nothing is open',
      () async {
        final connection = XrplConnection(XrplEndpoint.testnet);
        await connection.connect();
        addTearDown(connection.disconnect);

        await expectLater(
          pathFindStatus(connection),
          throwsA(isA<XrplConnectionException>()),
        );
        await expectLater(
          pathFindClose(connection),
          throwsA(isA<XrplConnectionException>()),
        );
        expect(connection.hasActivePathFindSubscription, isFalse);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'a real asynchronous update arrives on pathFindEvents',
      () async {
        final connection = XrplConnection(XrplEndpoint.testnet);
        await connection.connect();
        addTearDown(connection.disconnect);

        // Listen before creating, so an update that arrives right after
        // the create response cannot be missed.
        final firstUpdate = Completer<Map<String, dynamic>>();
        final updates = connection.pathFindEvents.listen((event) {
          if (!firstUpdate.isCompleted) firstUpdate.complete(event);
        });
        addTearDown(updates.cancel);

        await openSubscription(connection);

        // Regression check against the real server for the routing fix
        // in XrplConnection._handleIncomingMessage: streaming updates
        // are matched by "type" before the generic id-based routing, so
        // they reach pathFindEvents instead of being silently dropped.
        final update = await firstUpdate.future.timeout(
          const Duration(seconds: 45),
        );

        expect(update['type'], 'path_find');
        expect(update['alternatives'], isA<List<dynamic>>());

        await pathFindClose(connection);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
