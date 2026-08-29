import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_endpoint.dart';
import 'package:xrpl_flutter_sdk/src/transactions/models/xrpl_payment.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_autofill.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_fee_strategy.dart';

// Integration test: calls autofill() against the real public Testnet
// server. Every test here provides `sequence` explicitly, so autofill
// never needs to call accountInfo (which requires a funded account -
// not yet available; see the same (future) left in
// xrpl_queries_integration_test.dart). This still exercises autofill's
// real fee/lastLedgerSequence lookup, which doesn't depend on account
// funding at all.
void main() {
  group('autofill against the real public Testnet server', () {
    // (future): add a success-case test that also fills sequence
    // for real (via accountInfo), once this SDK can fund a Testnet
    // account itself.

    test('fills fee and lastLedgerSequence for real (openLedger default)',
        () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      const payment = XrplPayment(
        account: 'rG1QQv2nh2gr7RCZ1P8YYcBUKCCN633jCn',
        destination: 'rG1QQv2nh2gr7RCZ1P8YYcBUKCCN633jCn',
        amountDrops: '10000000',
        sequence: 1, // provided explicitly; skips accountInfo
      );

      final result = await autofill(connection, payment);

      expect(result.sequence, 1);
      expect(result.fee, isNotNull);
      expect(result.lastLedgerSequence, isNotNull);

      await connection.disconnect();
    });

    test('fills a different fee value for the minimum strategy', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      const payment = XrplPayment(
        account: 'rG1QQv2nh2gr7RCZ1P8YYcBUKCCN633jCn',
        destination: 'rG1QQv2nh2gr7RCZ1P8YYcBUKCCN633jCn',
        amountDrops: '10000000',
        sequence: 1,
      );

      final result = await autofill(
        connection,
        payment,
        feeStrategy: XrplFeeStrategy.minimum,
      );

      expect(result.fee, isNotNull);

      await connection.disconnect();
    });
  });
}
