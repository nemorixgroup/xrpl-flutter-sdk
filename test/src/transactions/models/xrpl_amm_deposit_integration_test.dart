@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

import '../../../support/xrpl_amm_test_pool.dart';

// Integration test: XrplAmmDeposit against the real public Testnet
// server. One real pool is created once and every deposit mode that can
// run on a non-empty pool is submitted against it. Each test reads the
// pool before and after with ammInfo, so the tests do not depend on
// their order.
//
// tfTwoAssetIfEmpty is not covered here: it needs an EMPTY pool, which
// can only be produced by withdrawing everything (AMMWithdraw, 0.4.5).

class _PoolState {
  const _PoolState({
    required this.drops,
    required this.token,
    required this.lp,
  });

  final BigInt drops;
  final double token;
  final double lp;
}

void main() {
  group('XrplAmmDeposit against the real public Testnet server', () {
    late XrplConnection connection;
    late XrplAmmTestAccounts accounts;
    late XrplAsset xrp;
    late XrplAsset token;

    Future<({_PoolState state, XrplAmmInfo info})> readPool() async {
      final info = await ammInfo(
        connection,
        asset: xrp,
        asset2: token,
        ledgerIndex: 'validated',
      );
      final sides = [info.amount, info.amount2];
      final xrpSide = sides.singleWhere((a) => a.isXrp);
      final tokenSide = sides.singleWhere((a) => !a.isXrp);
      return (
        state: _PoolState(
          drops: BigInt.parse(xrpSide.drops!),
          token: double.parse(tokenSide.value!),
          lp: double.parse(info.lpToken.value!),
        ),
        info: info,
      );
    }

    setUpAll(() async {
      connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();
      accounts = await createTestPool(connection);
      xrp = accounts.xrpAsset;
      token = accounts.tokenAsset;
    });

    tearDownAll(() async {
      await connection.disconnect();
    });

    test(
      'tfSingleAsset adds XRP, mints LP tokens, and pays the normal fee',
      () async {
        final before = (await readPool()).state;

        final deposit = XrplAmmDeposit.singleAsset(
          account: accounts.holder.classicAddress,
          asset: xrp,
          asset2: token,
          amount: const XrplCurrencyAmount.xrp('1000000'),
        );

        // AMMDeposit pays the normal transaction cost, not the owner
        // reserve that AMMCreate pays.
        final filled = await autofill(connection, deposit);
        final state = await serverState(connection);
        final reserveInc =
            (state['validated_ledger'] as Map<String, dynamic>)['reserve_inc'];
        expect(int.parse(filled.fee!), lessThan(int.parse('$reserveInc')));

        await submitExpectingSuccess(connection, deposit, accounts.holder);

        final after = (await readPool()).state;
        expect(after.drops, before.drops + BigInt.from(1000000));
        expect(after.token, before.token);
        expect(after.lp, greaterThan(before.lp));
      },
    );

    test('tfTwoAsset adds both assets in the pool proportion', () async {
      final before = (await readPool()).state;

      await submitExpectingSuccess(
        connection,
        XrplAmmDeposit.twoAsset(
          account: accounts.holder.classicAddress,
          asset: xrp,
          asset2: token,
          amount: const XrplCurrencyAmount.xrp('500000'),
          amount2: accounts.tokenAmount('5'),
        ),
        accounts.holder,
      );

      final after = (await readPool()).state;
      expect(after.drops, greaterThan(before.drops));
      expect(after.token, greaterThan(before.token));
      expect(after.lp, greaterThan(before.lp));
    });

    test('tfLPToken deposits proportionally for an exact LP amount', () async {
      final read = await readPool();
      final before = read.state;
      final lp = read.info.lpToken;

      await submitExpectingSuccess(
        connection,
        XrplAmmDeposit.lpToken(
          account: accounts.holder.classicAddress,
          asset: xrp,
          asset2: token,
          lpTokenOut: XrplCurrencyAmount.issued(
            currency: lp.currency.toString(),
            issuer: lp.issuer.toString(),
            value: '10',
          ),
        ),
        accounts.holder,
      );

      final after = (await readPool()).state;
      expect(after.lp, closeTo(before.lp + 10, 0.001));
      expect(after.drops, greaterThan(before.drops));
      expect(after.token, greaterThan(before.token));
    });

    test('tfOneAssetLPToken deposits XRP for an exact LP amount', () async {
      final read = await readPool();
      final before = read.state;
      final lp = read.info.lpToken;

      await submitExpectingSuccess(
        connection,
        XrplAmmDeposit.oneAssetLpToken(
          account: accounts.holder.classicAddress,
          asset: xrp,
          asset2: token,
          amount: const XrplCurrencyAmount.xrp('2000000'),
          lpTokenOut: XrplCurrencyAmount.issued(
            currency: lp.currency.toString(),
            issuer: lp.issuer.toString(),
            value: '10',
          ),
        ),
        accounts.holder,
      );

      final after = (await readPool()).state;
      expect(after.lp, closeTo(before.lp + 10, 0.001));
      expect(after.drops, greaterThan(before.drops));
      // The deposit never exceeds the maximum the caller allowed.
      expect(
        after.drops - before.drops,
        lessThanOrEqualTo(BigInt.from(2000000)),
      );
    });

    test('tfLimitLPToken deposits XRP under a maximum LP price', () async {
      final before = (await readPool()).state;

      await submitExpectingSuccess(
        connection,
        XrplAmmDeposit.limitLpToken(
          account: accounts.holder.classicAddress,
          asset: xrp,
          asset2: token,
          amount: const XrplCurrencyAmount.xrp('1000000'),
          // A generous cap of 2000 drops per LP token.
          ePrice: const XrplCurrencyAmount.xrp('2000'),
        ),
        accounts.holder,
      );

      final after = (await readPool()).state;
      expect(after.drops, greaterThan(before.drops));
      expect(after.lp, greaterThan(before.lp));
    });
  });
}
