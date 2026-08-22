import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_endpoint.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_connection_exception.dart';

void main() {
  group('XrplConnection.isConnected', () {
    test('is false immediately after construction', () {
      final connection = XrplConnection(XrplEndpoint.testnet);
      expect(connection.isConnected, isFalse);
    });
  });

  group('XrplConnection.disconnect without a prior connect', () {
    test('does not throw when never connected', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await expectLater(connection.disconnect(), completes);
    });

    test('leaves isConnected false', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.disconnect();
      expect(connection.isConnected, isFalse);
    });
  });

  group('XrplConnection construction', () {
    test('stores the endpoint it was created with', () {
      final connection = XrplConnection(XrplEndpoint.devnet);
      expect(connection.endpoint, XrplEndpoint.devnet);
    });
  });

  group('XrplConnection.request without a prior connect', () {
    test('throws XrplConnectionException instead of attempting to send',
        () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await expectLater(
        connection.request('server_info'),
        throwsA(isA<XrplConnectionException>()),
      );
    });
  });

  group('XrplConnection event streams', () {
    test(
        'ledgerEvents, transactionEvents, validationEvents, and '
        'serverEvents are all broadcast streams (support multiple '
        'listeners)', () {
      final connection = XrplConnection(XrplEndpoint.testnet);
      expect(connection.ledgerEvents.isBroadcast, isTrue);
      expect(connection.transactionEvents.isBroadcast, isTrue);
      expect(connection.validationEvents.isBroadcast, isTrue);
      expect(connection.serverEvents.isBroadcast, isTrue);
    });

    test(
        'ledgerEvents supports multiple simultaneous listeners without '
        'error', () async {
      // Broadcast streams return a new wrapper object on each .stream
      // access (this is normal Dart behavior, not a bug), so identity
      // isn't the right thing to check - what matters is that more
      // than one listener can subscribe at once without throwing, the
      // functional guarantee a broadcast stream actually provides.
      final connection = XrplConnection(XrplEndpoint.testnet);
      final subscriptionA = connection.ledgerEvents.listen((_) {});
      final subscriptionB = connection.ledgerEvents.listen((_) {});

      expect(subscriptionA, isNotNull);
      expect(subscriptionB, isNotNull);

      await subscriptionA.cancel();
      await subscriptionB.cancel();
    });
  });
}
