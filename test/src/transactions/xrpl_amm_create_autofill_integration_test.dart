@Timeout(Duration(minutes: 2))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

// Integration tests for autofill with AMMCreate against the real
// Testnet server: the fee must be the network's incremental owner
// reserve, read from server_state, not the ordinary transaction cost.
void main() {
  group('autofill for AMMCreate against Testnet', () {
    test('uses the incremental owner reserve as the fee', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      addTearDown(connection.disconnect);
      await connection.connect();
      final wallet = await fundTestWallet(connection);

      final state = await serverState(connection);
      final validated = state['validated_ledger'] as Map<String, dynamic>;
      final reserveInc = validated['reserve_inc'] as int;

      final ready = await autofill(
        connection,
        XrplAmmCreate(
          account: wallet.classicAddress,
          amount: const XrplCurrencyAmount.xrp('10000000'),
          amount2: XrplCurrencyAmount.issued(
            currency: 'TST',
            issuer: wallet.classicAddress,
            value: '25',
          ),
          tradingFee: 500,
        ),
      );

      expect(ready.fee, reserveInc.toString());
      expect(ready.sequence, isA<int>());
      expect(ready.lastLedgerSequence, isA<int>());
    });

    test('keeps the fee the caller sets instead of the owner reserve',
        () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      addTearDown(connection.disconnect);
      await connection.connect();
      final wallet = await fundTestWallet(connection);

      final ready = await autofill(
        connection,
        XrplAmmCreate(
          account: wallet.classicAddress,
          amount: const XrplCurrencyAmount.xrp('10000000'),
          amount2: XrplCurrencyAmount.issued(
            currency: 'TST',
            issuer: wallet.classicAddress,
            value: '25',
          ),
          tradingFee: 500,
          fee: '250000',
        ),
      );

      expect(ready.fee, '250000');
    });

    test('an ordinary transaction still gets the standard fee', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      addTearDown(connection.disconnect);
      await connection.connect();
      final wallet = await fundTestWallet(connection);

      final state = await serverState(connection);
      final validated = state['validated_ledger'] as Map<String, dynamic>;
      final reserveInc = validated['reserve_inc'] as int;

      final ready = await autofill(
        connection,
        XrplPayment(
          account: wallet.classicAddress,
          destination: wallet.classicAddress,
          amountDrops: '1000000',
        ),
      );

      // An ordinary Payment pays the usual small fee, far below the
      // owner reserve an AMMCreate has to destroy.
      expect(int.parse(ready.fee!), lessThan(reserveInc));
    });
  });
}
