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
}
