import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_endpoint.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_subscriptions.dart';

// Integration test: calls the subscribe/unsubscribe helpers against
// the real public Testnet server. Kept in test/src/ alongside
// xrpl_connection_integration_test.dart and
// xrpl_queries_integration_test.dart, per this SDK's convention for
// network-dependent tests.
void main() {
  group(
      'subscribeToLedger / unsubscribeFromLedger against the real '
      'public Testnet server', () {
    test('subscribing succeeds and a real ledgerClosed event arrives',
        () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      await subscribeToLedger(connection);

      final event = await connection.ledgerEvents.first.timeout(
        const Duration(seconds: 15),
      );
      expect(event['type'], 'ledgerClosed');

      await unsubscribeFromLedger(connection);
      await connection.disconnect();
    });
  });

  group(
      'subscribeToServer / unsubscribeFromServer against the real '
      'public Testnet server', () {
    test('subscribing succeeds without throwing', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      await expectLater(subscribeToServer(connection), completes);
      await expectLater(unsubscribeFromServer(connection), completes);

      await connection.disconnect();
    });
  });

  group(
      'subscribeToTransactions / unsubscribeFromTransactions against '
      'the real public Testnet server', () {
    test('subscribing succeeds without throwing (default, validated only)',
        () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      await expectLater(subscribeToTransactions(connection), completes);
      await expectLater(
        unsubscribeFromTransactions(connection),
        completes,
      );

      await connection.disconnect();
    });

    test('subscribing with includeProposed: true succeeds without throwing',
        () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      await expectLater(
        subscribeToTransactions(connection, includeProposed: true),
        completes,
      );
      await expectLater(
        unsubscribeFromTransactions(connection, includeProposed: true),
        completes,
      );

      await connection.disconnect();
    });
  });

  group(
      'subscribeToValidations / unsubscribeFromValidations against the '
      'real public Testnet server', () {
    test('subscribing succeeds without throwing', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      await expectLater(subscribeToValidations(connection), completes);
      await expectLater(
        unsubscribeFromValidations(connection),
        completes,
      );

      await connection.disconnect();
    });
  });
}
