@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

import '../../../support/xrpl_amm_test_pool.dart';

// Integration test: XrplAmmVote against the real public Testnet server.
//
// The first two tests share one real pool, whose only liquidity
// provider is the holder, so each vote fully decides the pool's fee and
// the tests do not depend on their order. The weighted-average test
// builds a pool of its own because it adds a second provider, and the
// last test only needs an account that holds no LP tokens.
//
// Not covered here, on purpose:
//   - tecAMM_FAILED_VOTE: it needs eight accounts holding more LP
//     tokens than the voter, which is too much setup for a Testnet run.
//   - The pool's vote slots: amm_info reports them, but this SDK does
//     not expose them yet (0.5.0-dev audit), so the tests read the
//     resulting trading fee instead.

Future<int> _tradingFeeOf(
  XrplConnection connection,
  XrplAmmTestAccounts accounts,
) async {
  final info = await ammInfo(
    connection,
    asset: accounts.xrpAsset,
    asset2: accounts.tokenAsset,
    ledgerIndex: 'validated',
  );
  return int.parse('${info.tradingFee}');
}

XrplAmmVote _voteFor(
  XrplAmmTestAccounts accounts,
  XrplWallet voter,
  int tradingFee,
) {
  return XrplAmmVote(
    account: voter.classicAddress,
    asset: accounts.xrpAsset,
    asset2: accounts.tokenAsset,
    tradingFee: tradingFee,
  );
}

void main() {
  group('XrplAmmVote against the real public Testnet server', () {
    late XrplConnection connection;
    late XrplAmmTestAccounts accounts;

    setUpAll(() async {
      connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();
      accounts = await createTestPool(connection);
    });

    tearDownAll(() async {
      await connection.disconnect();
    });

    test(
      'the only provider sets the pool fee and pays the normal fee',
      () async {
        // The pool was created with a trading fee of 500.
        expect(await _tradingFeeOf(connection, accounts), 500);

        final vote = _voteFor(accounts, accounts.holder, 300);

        // The official page states no special cost for AMMVote, so it
        // should pay the normal transaction cost, not the owner reserve
        // that AMMCreate pays.
        final filled = await autofill(connection, vote);
        final state = await serverState(connection);
        final reserveInc =
            (state['validated_ledger'] as Map<String, dynamic>)['reserve_inc'];
        expect(int.parse(filled.fee!), lessThan(int.parse('$reserveInc')));

        await submitExpectingSuccess(connection, vote, accounts.holder);

        // With a single voter holding every LP token, the weighted
        // average is that voter's own vote.
        expect(await _tradingFeeOf(connection, accounts), 300);
      },
    );

    test('accepts the limits 0 and 1000', () async {
      await submitExpectingSuccess(
        connection,
        _voteFor(accounts, accounts.holder, 0),
        accounts.holder,
      );
      expect(await _tradingFeeOf(connection, accounts), 0);

      await submitExpectingSuccess(
        connection,
        _voteFor(accounts, accounts.holder, 1000),
        accounts.holder,
      );
      expect(await _tradingFeeOf(connection, accounts), 1000);
    });

    test(
      'a second provider moves the fee by its share of the LP tokens',
      () async {
        final ownConnection = XrplConnection(XrplEndpoint.testnet);
        await ownConnection.connect();
        addTearDown(ownConnection.disconnect);

        final own = await createTestPool(ownConnection);
        expect(await _tradingFeeOf(ownConnection, own), 500);

        // A second provider joins with 1 XRP, about 9% of the pool's LP
        // tokens, and votes for the maximum fee.
        final provider = await fundTestWallet(ownConnection);
        await submitExpectingSuccess(
          ownConnection,
          XrplAmmDeposit.singleAsset(
            account: provider.classicAddress,
            asset: own.xrpAsset,
            asset2: own.tokenAsset,
            amount: const XrplCurrencyAmount.xrp('1000000'),
          ),
          provider,
        );
        await submitExpectingSuccess(
          ownConnection,
          _voteFor(own, provider, 1000),
          provider,
        );

        // The fee is the average of the votes weighted by LP tokens, so
        // it moves from 500 towards 1000, but stays much closer to the
        // holder's 500 because the holder owns most of the pool. The
        // exact value depends on the server's rounding, so only the
        // range is checked.
        final fee = await _tradingFeeOf(ownConnection, own);
        expect(fee, greaterThan(500));
        expect(fee, lessThan(750));
      },
    );

    test('an account holding no LP tokens cannot vote', () async {
      final outsider = await fundTestWallet(connection);

      final result = await sendTransaction(
        connection,
        _voteFor(accounts, outsider, 300),
        outsider,
      );

      expect(result['validated'], isTrue);
      expect(transactionResultOf(result), 'tecAMM_INVALID_TOKENS');
    });
  });
}
