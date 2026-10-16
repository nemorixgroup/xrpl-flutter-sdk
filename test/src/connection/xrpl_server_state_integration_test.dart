import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

// Integration tests for serverState against the real Testnet server.
// The reserve_inc check matters most: autofill relies on it as the Fee
// of AMMCreate, so its shape and unit (integer drops) are confirmed
// here against the real server instead of assumed.
void main() {
  group('serverState (Testnet)', () {
    test('returns a state object with a validated_ledger', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      addTearDown(connection.disconnect);
      await connection.connect();

      final state = await serverState(connection);

      expect(state['validated_ledger'], isA<Map<String, dynamic>>());
    });

    test('validated_ledger reports reserves as positive integers', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      addTearDown(connection.disconnect);
      await connection.connect();

      final state = await serverState(connection);
      final validated = state['validated_ledger'] as Map<String, dynamic>;

      expect(validated['reserve_base'], isA<int>());
      expect(validated['reserve_inc'], isA<int>());
      expect(validated['reserve_inc'] as int, greaterThan(0));
      expect(validated['base_fee'], isA<int>());
    });

    test('throws XrplConnectionException when not connected', () {
      final connection = XrplConnection(XrplEndpoint.testnet);

      expect(
        serverState(connection),
        throwsA(isA<XrplConnectionException>()),
      );
    });
  });
}
