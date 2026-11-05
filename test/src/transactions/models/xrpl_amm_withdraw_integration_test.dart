@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

import '../../../support/xrpl_amm_test_pool.dart';

// Integration test: XrplAmmWithdraw against the real public Testnet
// server.
//
// The first three tests share one real pool, whose only liquidity
// provider is the holder; each reads the pool before and after with
// ammInfo, so they do not depend on their order. The last two need a
// pool of their own because they change who provides liquidity, or
// delete the pool.
//
// Not covered here, on purpose:
//   - tfOneAssetLPToken and tfLimitLPToken: the official AMMWithdraw
//     page does not say how Amount (in the first) or EPrice (in the
//     second) are interpreted, and its only example is tfTwoAsset.
//     They are covered by the codec and model tests only.
//   - AMMDeposit's tfTwoAssetIfEmpty: withdrawing everything deletes
//     the pool instead of leaving it empty, so an empty pool still
//     cannot be produced with two wallets.

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

Future<({_PoolState state, XrplAmmInfo info})> _readPool(
  XrplConnection connection,
  XrplAmmTestAccounts accounts,
) async {
  final info = await ammInfo(
    connection,
    asset: accounts.xrpAsset,
    asset2: accounts.tokenAsset,
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

void main() {
  group('XrplAmmWithdraw against the real public Testnet server', () {
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
      'tfLPToken redeems an exact LP amount for both assets and pays the '
      'normal fee',
      () async {
        final read = await _readPool(connection, accounts);
        final before = read.state;
        final lp = read.info.lpToken;

        final withdraw = XrplAmmWithdraw.lpToken(
          account: accounts.holder.classicAddress,
          asset: accounts.xrpAsset,
          asset2: accounts.tokenAsset,
          lpTokenIn: XrplCurrencyAmount.issued(
            currency: lp.currency.toString(),
            issuer: lp.issuer.toString(),
            value: '10',
          ),
        );

        // The official page states no special cost for AMMWithdraw, so
        // it should pay the normal transaction cost, not the owner
        // reserve that AMMCreate pays.
        final filled = await autofill(connection, withdraw);
        final state = await serverState(connection);
        final reserveInc =
            (state['validated_ledger'] as Map<String, dynamic>)['reserve_inc'];
        expect(int.parse(filled.fee!), lessThan(int.parse('$reserveInc')));

        await submitExpectingSuccess(connection, withdraw, accounts.holder);

        final after = (await _readPool(connection, accounts)).state;
        expect(after.lp, closeTo(before.lp - 10, 0.001));
        expect(after.drops, lessThan(before.drops));
        expect(after.token, lessThan(before.token));
      },
    );

    test('tfSingleAsset withdraws XRP, rounding in the pool favor', () async {
      final before = (await _readPool(connection, accounts)).state;

      await submitExpectingSuccess(
        connection,
        XrplAmmWithdraw.singleAsset(
          account: accounts.holder.classicAddress,
          asset: accounts.xrpAsset,
          asset2: accounts.tokenAsset,
          amount: const XrplCurrencyAmount.xrp('500000'),
        ),
        accounts.holder,
      );

      final after = (await _readPool(connection, accounts)).state;
      final withdrawn = before.drops - after.drops;
      // The server rounds in the pool's favor, so it may pay a few drops
      // less than requested (1 drop less on the first Testnet run), but
      // never more.
      expect(withdrawn, lessThanOrEqualTo(BigInt.from(500000)));
      expect(withdrawn, greaterThanOrEqualTo(BigInt.from(499990)));
      expect(after.token, before.token);
      expect(after.lp, lessThan(before.lp));
    });

    test('tfTwoAsset withdraws both assets in the pool proportion', () async {
      final before = (await _readPool(connection, accounts)).state;

      // Ask for 0.3 XRP and the matching amount of the token, rounded
      // down to 6 decimals, so the request follows the pool's current
      // ratio whatever the earlier tests left behind.
      const dropsToWithdraw = 300000;
      final tokenToWithdraw =
          (before.token * dropsToWithdraw / before.drops.toDouble() * 1e6)
                  .floorToDouble() /
              1e6;

      await submitExpectingSuccess(
        connection,
        XrplAmmWithdraw.twoAsset(
          account: accounts.holder.classicAddress,
          asset: accounts.xrpAsset,
          asset2: accounts.tokenAsset,
          amount: const XrplCurrencyAmount.xrp('$dropsToWithdraw'),
          amount2: accounts.tokenAmount(tokenToWithdraw.toStringAsFixed(6)),
        ),
        accounts.holder,
      );

      final after = (await _readPool(connection, accounts)).state;
      expect(after.drops, lessThan(before.drops));
      expect(after.token, lessThan(before.token));
      expect(after.lp, lessThan(before.lp));
    });

    test(
      'tfOneAssetWithdrawAll with an Amount of 0 returns a second '
      "provider's whole stake as XRP",
      () async {
        final ownConnection = XrplConnection(XrplEndpoint.testnet);
        await ownConnection.connect();
        addTearDown(ownConnection.disconnect);

        final own = await createTestPool(ownConnection);
        final original = (await _readPool(ownConnection, own)).state;

        // A second provider joins with 1 XRP, so that withdrawing its
        // whole stake as one asset leaves the pool (and the holder's
        // stake) intact.
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
        final deposited = (await _readPool(ownConnection, own)).state;
        expect(deposited.lp, greaterThan(original.lp));

        // The provider redeems every LP token it holds, as XRP. An
        // Amount of 0 means it succeeds if any positive amount comes
        // out, which is the case the model's zero rule exists for.
        await submitExpectingSuccess(
          ownConnection,
          XrplAmmWithdraw.oneAssetWithdrawAll(
            account: provider.classicAddress,
            asset: own.xrpAsset,
            asset2: own.tokenAsset,
            amount: const XrplCurrencyAmount.xrp('0'),
          ),
          provider,
        );

        final after = (await _readPool(ownConnection, own)).state;
        // Only the holder's LP tokens are left, and the fees the
        // provider paid stay in the pool.
        expect(after.lp, closeTo(original.lp, 0.01));
        expect(after.drops, greaterThanOrEqualTo(original.drops));
        expect(after.drops, lessThan(deposited.drops));
      },
    );

    test(
      'tfWithdrawAll by the only provider empties and deletes the pool',
      () async {
        final ownConnection = XrplConnection(XrplEndpoint.testnet);
        await ownConnection.connect();
        addTearDown(ownConnection.disconnect);

        final own = await createTestPool(ownConnection);

        final result = await submitExpectingSuccess(
          ownConnection,
          XrplAmmWithdraw.withdrawAll(
            account: own.holder.classicAddress,
            asset: own.xrpAsset,
            asset2: own.tokenAsset,
          ),
          own.holder,
        );

        // The last withdrawal deletes the AMM entry.
        final nodes = (result['meta'] as Map<String, dynamic>)['AffectedNodes']
            as List<dynamic>;
        final deletedAmm = nodes.any((node) {
          final deletedNode = (node as Map<String, dynamic>)['DeletedNode']
              as Map<String, dynamic>?;
          return deletedNode?['LedgerEntryType'] == 'AMM';
        });
        expect(
          deletedAmm,
          isTrue,
          reason: 'Expected a DeletedNode of type AMM in the metadata',
        );

        // And the pool can no longer be read.
        await expectLater(
          ammInfo(
            ownConnection,
            asset: own.xrpAsset,
            asset2: own.tokenAsset,
          ),
          throwsA(isA<XrplConnectionException>()),
        );
      },
    );
  });
}
