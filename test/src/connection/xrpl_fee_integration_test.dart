import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_endpoint.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_queries.dart';

// Integration test: calls fee() against the real public Testnet
// server. Kept alongside xrpl_queries_integration_test.dart, per this
// SDK's convention for network-dependent tests.
void main() {
  group('fee against the real public Testnet server', () {
    test('returns drops and the current ledger index', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      final feeInfo = await fee(connection);

      final drops = feeInfo['drops'] as Map<String, dynamic>;
      expect(drops['open_ledger_fee'], isA<String>());
      expect(drops['minimum_fee'], isA<String>());
      expect(drops['median_fee'], isA<String>());
      expect(drops['base_fee'], isA<String>());
      expect(feeInfo['ledger_current_index'], isA<int>());

      await connection.disconnect();
    });
  });
}
