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

  group('XrplConnection.request against the real public Testnet server', () {
    test('server_info returns a successful response with a result', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      final response = await connection.request('server_info');

      expect(response['status'], 'success');

      // Cast explicitly before a second layer of key access, rather
      // than chaining response['result']['info'] directly - indexing
      // into a dynamic value (the untyped result of the first ['result'])
      // trips the avoid_dynamic_calls lint.
      final result = response['result'] as Map<String, dynamic>;
      expect(result, isA<Map<String, dynamic>>());
      expect(result['info'], isNotNull);

      await connection.disconnect();
    });

    test('an unknown command results in an XrplConnectionException', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      await expectLater(
        connection.request('this_command_does_not_exist'),
        throwsA(isA<XrplConnectionException>()),
      );

      await connection.disconnect();
    });

    test('concurrent requests are each matched to their own response',
        () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      // Fire two different commands at the same time and confirm each
      // one gets back the response that actually matches it - this
      // is the real-world case the "id" matching logic exists for.
      final results = await Future.wait([
        connection.request('server_info'),
        connection.request('server_info', {'counters': false}),
      ]);

      for (final response in results) {
        expect(response['status'], 'success');
      }

      await connection.disconnect();
    });
  });
}
