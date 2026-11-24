@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

import '../../../support/xrpl_amm_test_pool.dart';

// Integration test: XrplAmmBid against the real public Testnet server.
//
// A bid changes the pool's auction slot, so every test that wins a slot
// builds a pool of its own and the tests do not depend on their order.
// The two tests that never win a slot (a bid that fails, and an account
// holding no LP tokens) share one pool, because a failed bid leaves the
// slot untouched.
//
// The tests never assume what the slot holds before the first bid (it
// is optional in the pool's ledger entry). They only compare what the
// slot shows after a bid, using ranges where the exact value depends on
// the server's rounding or on elapsed time.
//
// Not covered here, on purpose:
//   - Prices after the first 72-minute interval, and the refund once the
//     slot has been held for a while: they depend on elapsed time, and
//     a Testnet run cannot wait hours.
//   - An expired slot and tecAMM_EMPTY.

Future<XrplAmmInfo> _poolInfo(
  XrplConnection connection,
  XrplAmmTestAccounts accounts, {
  String? account,
}) {
  return ammInfo(
    connection,
    asset: accounts.xrpAsset,
    asset2: accounts.tokenAsset,
    account: account,
    ledgerIndex: 'validated',
  );
}

/// The LP tokens in [info]: the pool's total, or the balance of the
/// account the request named.
double _lpValue(XrplAmmInfo info) => double.parse(info.lpToken.value!);

/// What the slot holder paid, in LP tokens.
double _slotPrice(XrplAmmInfo info) {
  return double.parse(info.auctionSlot!.price.value!);
}

/// An amount of the pool's own LP tokens, in the shape a bid needs.
XrplCurrencyAmount _lp(XrplAmmInfo info, String value) {
  return XrplCurrencyAmount.issued(
    currency: info.lpToken.currency,
    issuer: info.lpToken.issuer,
    value: value,
  );
}

XrplAmmBid _bidFor(
  XrplAmmTestAccounts accounts,
  XrplWallet bidder, {
  XrplCurrencyAmount? bidMin,
  XrplCurrencyAmount? bidMax,
  List<String>? authAccounts,
}) {
  return XrplAmmBid(
    account: bidder.classicAddress,
    asset: accounts.xrpAsset,
    asset2: accounts.tokenAsset,
    bidMin: bidMin,
    bidMax: bidMax,
    authAccounts: authAccounts,
  );
}

class _OwnPool {
  const _OwnPool(this.connection, this.accounts);

  final XrplConnection connection;
  final XrplAmmTestAccounts accounts;
}

Future<_OwnPool> _createOwnPool() async {
  final connection = XrplConnection(XrplEndpoint.testnet);
  await connection.connect();
  addTearDown(connection.disconnect);
  return _OwnPool(connection, await createTestPool(connection));
}

void main() {
  group('XrplAmmBid against the real public Testnet server', () {
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
      'the only provider wins the slot at the minimum price and an '
      'authorized account is recorded',
      () async {
        final own = await _createOwnPool();
        final pool = own.accounts;
        final authorized = await fundTestWallet(own.connection);

        final before = await _poolInfo(own.connection, pool);
        expect(before.tradingFee, 500);
        final lpBefore = _lpValue(before);
        // The official page gives the minimum price as the LP tokens in
        // circulation times the trading fee divided by 25.
        final minimum = lpBefore * (before.tradingFee / 100000) / 25;

        final bid = _bidFor(
          pool,
          pool.holder,
          authAccounts: [authorized.classicAddress],
        );

        // The official page states no special cost for AMMBid, so it
        // should pay the normal transaction cost, not the owner reserve
        // that AMMCreate pays.
        final filled = await autofill(own.connection, bid);
        final state = await serverState(own.connection);
        final reserveInc =
            (state['validated_ledger'] as Map<String, dynamic>)['reserve_inc'];
        expect(int.parse(filled.fee!), lessThan(int.parse('$reserveInc')));

        await submitExpectingSuccess(own.connection, bid, pool.holder);

        final after = await _poolInfo(own.connection, pool);
        final slot = after.auctionSlot!;
        expect(slot.account, pool.holder.classicAddress);
        expect(slot.authAccounts, [authorized.classicAddress]);
        // One tenth of the pool's 500 trading fee.
        expect(slot.discountedFee, 50);
        expect(_slotPrice(after), closeTo(minimum, 0.01));
        // What the winner paid left the LP tokens in circulation.
        expect(lpBefore - _lpValue(after), closeTo(_slotPrice(after), 0.01));
      },
    );

    test('BidMin and BidMax together set the price within that range',
        () async {
      // The older version of the official page said BidMin and BidMax
      // cannot both be given, and the current one does not say. This
      // test records what the server does.
      final own = await _createOwnPool();
      final pool = own.accounts;
      final before = await _poolInfo(own.connection, pool);

      await submitExpectingSuccess(
        own.connection,
        _bidFor(
          pool,
          pool.holder,
          bidMin: _lp(before, '4'),
          bidMax: _lp(before, '10'),
        ),
        pool.holder,
      );

      final after = await _poolInfo(own.connection, pool);
      expect(after.auctionSlot!.account, pool.holder.classicAddress);
      expect(_slotPrice(after), greaterThanOrEqualTo(4));
      expect(_slotPrice(after), lessThanOrEqualTo(10));
    });

    test(
      'a second provider outbids the first and the first is refunded',
      () async {
        final own = await _createOwnPool();
        final pool = own.accounts;
        final conn = own.connection;
        final holder = pool.holder.classicAddress;

        await submitExpectingSuccess(
          conn,
          _bidFor(pool, pool.holder),
          pool.holder,
        );
        final afterFirst = await _poolInfo(conn, pool);
        final firstPrice = _slotPrice(afterFirst);
        final holderAfterBid = _lpValue(
          await _poolInfo(conn, pool, account: holder),
        );

        // A second provider joins with 1 XRP, which gives it enough LP
        // tokens to outbid the holder.
        final provider = await fundTestWallet(conn);
        await submitExpectingSuccess(
          conn,
          XrplAmmDeposit.singleAsset(
            account: provider.classicAddress,
            asset: pool.xrpAsset,
            asset2: pool.tokenAsset,
            amount: const XrplCurrencyAmount.xrp('1000000'),
          ),
          provider,
        );

        await submitExpectingSuccess(
          conn,
          _bidFor(pool, provider, bidMax: _lp(afterFirst, '100')),
          provider,
        );

        final after = await _poolInfo(conn, pool);
        expect(after.auctionSlot!.account, provider.classicAddress);
        // Outbidding costs the previous price plus 5%, plus the minimum
        // price, so it is above 105% of the first price and below the
        // BidMax. The exact value depends on the server's rounding.
        expect(_slotPrice(after), greaterThan(firstPrice * 1.05));
        expect(_slotPrice(after), lessThan(100));

        // The holder was outbid within the first interval of the slot,
        // so it gets back part of its bid: its LP tokens grew.
        final holderAfterOutbid = _lpValue(
          await _poolInfo(conn, pool, account: holder),
        );
        expect(holderAfterOutbid, greaterThan(holderAfterBid));
      },
    );

    test('a BidMax below the slot price fails with tecAMM_FAILED', () async {
      final info = await _poolInfo(connection, accounts);

      // The minimum price is about 3.16 LP tokens, so 1 cannot win.
      final result = await sendTransaction(
        connection,
        _bidFor(accounts, accounts.holder, bidMax: _lp(info, '1')),
        accounts.holder,
      );

      expect(result['validated'], isTrue);
      expect(transactionResultOf(result), 'tecAMM_FAILED');
    });

    test('an account holding no LP tokens cannot win the slot', () async {
      final outsider = await fundTestWallet(connection);

      final result = await sendTransaction(
        connection,
        _bidFor(accounts, outsider),
        outsider,
      );

      expect(result['validated'], isTrue);
      expect(transactionResultOf(result), 'tecAMM_INVALID_TOKENS');
    });
  });
}
