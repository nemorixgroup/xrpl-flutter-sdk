@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

import '../../../support/xrpl_amm_test_pool.dart';

// Integration test: XrplAmmCreate and ammInfo against the real public
// Testnet server, end to end (autofill with the owner-reserve fee,
// signing, submission, ledger metadata, and reading the pool back).
//
// The setup a real pool needs (two wallets, Default Ripple, a trust
// line and a token transfer) lives in test/support/xrpl_amm_test_pool.dart,
// which the other AMM integration tests share.

void main() {
  group('XrplAmmCreate and ammInfo against the real public Testnet server', () {
    test(
      'creates a real pool, reads it back with ammInfo, and a second '
      'AMMCreate for the same pair is rejected',
      () async {
        final connection = XrplConnection(XrplEndpoint.testnet);
        await connection.connect();
        addTearDown(connection.disconnect);

        final accounts = await prepareTokenHolder(connection);
        final holder = accounts.holder;

        // Holder creates the pool: 5 XRP + 50 TST, 0.5% trading fee.
        final ammCreate = XrplAmmCreate(
          account: holder.classicAddress,
          amount: const XrplCurrencyAmount.xrp('5000000'),
          amount2: accounts.tokenAmount('50'),
          tradingFee: 500,
        );

        // autofill must have used the owner reserve, not the base fee.
        final filled = await autofill(connection, ammCreate);
        final state = await serverState(connection);
        final reserveInc =
            (state['validated_ledger'] as Map<String, dynamic>)['reserve_inc'];
        expect(filled.fee, reserveInc.toString());

        final created = await submitExpectingSuccess(
          connection,
          ammCreate,
          holder,
        );

        final nodes = (created['meta'] as Map<String, dynamic>)['AffectedNodes']
            as List<dynamic>;
        final createdAmm = nodes.any((node) {
          final createdNode = (node as Map<String, dynamic>)['CreatedNode']
              as Map<String, dynamic>?;
          return createdNode?['LedgerEntryType'] == 'AMM';
        });
        expect(
          createdAmm,
          isTrue,
          reason: 'Expected a CreatedNode of type AMM in the metadata',
        );

        // Read the pool back. Do not assume amount/amount2 order.
        final info = await ammInfo(
          connection,
          asset: accounts.xrpAsset,
          asset2: accounts.tokenAsset,
          ledgerIndex: 'validated',
        );

        expect(info.tradingFee, 500);
        expect(info.validated, isTrue);
        final sides = [info.amount, info.amount2];
        final xrpSide = sides.singleWhere((a) => a.isXrp);
        final tokenSide = sides.singleWhere((a) => !a.isXrp);
        expect(xrpSide.drops, '5000000');
        expect(double.parse(tokenSide.value!), 50);
        expect(tokenSide.currency, xrplAmmTestCurrency);
        expect(tokenSide.issuer, accounts.issuer.classicAddress);
        expect(info.lpToken.isXrp, isFalse);

        // The same pool looked up by the AMM account.
        final byAccount = await ammInfo(
          connection,
          ammAccount: info.account,
          ledgerIndex: 'validated',
        );
        expect(byAccount.account, info.account);

        // A second AMMCreate for the same pair is rejected by the
        // server (tecDUPLICATE per the AMMCreate documentation).
        final duplicate = await sendTransaction(
          connection,
          XrplAmmCreate(
            account: holder.classicAddress,
            amount: const XrplCurrencyAmount.xrp('1000000'),
            amount2: accounts.tokenAmount('10'),
            tradingFee: 500,
          ),
          holder,
        );
        expect(duplicate['validated'], isTrue);
        expect(transactionResultOf(duplicate), 'tecDUPLICATE');
      },
    );

    test('ammInfo for a pair with no pool throws actNotFound', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();
      addTearDown(connection.disconnect);

      final issuer = await fundTestWallet(connection);

      expect(
        () => ammInfo(
          connection,
          asset: const XrplAsset.xrp(),
          asset2: XrplAsset.issued(
            currency: xrplAmmTestCurrency,
            issuer: issuer.classicAddress,
          ),
        ),
        throwsA(isA<XrplConnectionException>()),
      );
    });
  });
}
