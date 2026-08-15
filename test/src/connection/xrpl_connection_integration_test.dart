import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_endpoint.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_connection_exception.dart';

// Integration test: opens a real WebSocket connection to the official
// public Testnet server. Kept separate from the pure unit tests in
// test/connection/xrpl_connection_test.dart because these depend on
// network availability and are slower - a failure here can mean
// "the public Testnet server is down right now," not necessarily
// "this SDK's code is broken."
void main() {
  group('XrplConnection against the real public Testnet server', () {
    test('connect() succeeds and sets isConnected to true', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      expect(connection.isConnected, isFalse);

      await connection.connect();
      expect(connection.isConnected, isTrue);

      await connection.disconnect();
    });

    test('disconnect() closes the connection and resets isConnected', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      await connection.disconnect();
      expect(connection.isConnected, isFalse);
    });

    test('connecting twice without disconnecting throws', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      expect(
        connection.connect,
        throwsA(isA<XrplConnectionException>()),
      );

      await connection.disconnect();
    });

    test('disconnect() followed by connect() reopens the connection', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();
      await connection.disconnect();

      await connection.connect();
      expect(connection.isConnected, isTrue);

      await connection.disconnect();
    });
  });
}
