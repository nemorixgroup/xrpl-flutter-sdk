import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

// Unit tests for ammInfo's client-side validation and for parsing an
// amm_info response. Parsing is tested with the example response from
// the official amm_info documentation, so no server is needed. The
// real-server behavior is covered by the integration tests.
void main() {
  group('ammInfo validation', () {
    final connection = XrplConnection(XrplEndpoint.testnet);
    final tst = XrplAsset.issued(
      currency: 'TST',
      issuer: 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd',
    );

    test('throws ArgumentError when nothing identifies the pool', () {
      expect(() => ammInfo(connection), throwsArgumentError);
    });

    test('throws ArgumentError when only asset is given', () {
      expect(
        () => ammInfo(connection, asset: const XrplAsset.xrp()),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when only asset2 is given', () {
      expect(() => ammInfo(connection, asset2: tst), throwsArgumentError);
    });

    test('throws ArgumentError when ledgerIndex is not an int or a String', () {
      expect(
        () => ammInfo(
          connection,
          ammAccount: 'rp9E3FN3gNmvePGhYnf414T2TkUuoxu8vM',
          ledgerIndex: 1.5,
        ),
        throwsArgumentError,
      );
    });

    test(
        'accepts ammAccount alone, failing later only for lack of a '
        'connection', () async {
      await expectLater(
        ammInfo(
          connection,
          ammAccount: 'rp9E3FN3gNmvePGhYnf414T2TkUuoxu8vM',
        ),
        throwsA(isNot(isA<ArgumentError>())),
      );
    });

    test(
        'accepts both assets, failing later only for lack of a '
        'connection', () async {
      await expectLater(
        ammInfo(
          connection,
          asset: const XrplAsset.xrp(),
          asset2: tst,
          ledgerIndex: 'validated',
        ),
        throwsA(isNot(isA<ArgumentError>())),
      );
    });
  });

  group('XrplAmmInfo.fromJson', () {
    test('parses the example response from the official documentation', () {
      final info = XrplAmmInfo.fromJson({
        'amm': {
          'account': 'rp9E3FN3gNmvePGhYnf414T2TkUuoxu8vM',
          'amount': '296890496',
          'amount2': {
            'currency': 'TST',
            'issuer': 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd',
            'value': '25.81656470648473',
          },
          'asset2_frozen': false,
          'auction_slot': {
            'account': 'rJVUeRqDFNs2xqA7ncVE6ZoAhPUoaJJSQm',
            'auth_accounts': [
              {'account': 'r3f2WpQMsAd8k4Zoijv2PZ78EYFJ2EdvgV'},
              {'account': 'rnW8FAPgpQgA6VoESnVrUVJHBdq9QAtRZs'},
            ],
            'discounted_fee': 60,
            'expiration': '2023-Jan-26 00:28:40.000000000 UTC',
            'price': {
              'currency': '039C99CD9AB0B70B32ECDA51EAAE471625608EA2',
              'issuer': 'rp9E3FN3gNmvePGhYnf414T2TkUuoxu8vM',
              'value': '0',
            },
            'time_interval': 0,
          },
          'lp_token': {
            'currency': '039C99CD9AB0B70B32ECDA51EAAE471625608EA2',
            'issuer': 'rp9E3FN3gNmvePGhYnf414T2TkUuoxu8vM',
            'value': '87533.41976112682',
          },
          'trading_fee': 600,
          'vote_slots': [
            {
              'account': 'rJVUeRqDFNs2xqA7ncVE6ZoAhPUoaJJSQm',
              'trading_fee': 600,
              'vote_weight': 9684,
            },
          ],
        },
        'ledger_current_index': 316725,
        'validated': false,
      });

      expect(info.account, 'rp9E3FN3gNmvePGhYnf414T2TkUuoxu8vM');
      expect(info.amount.isXrp, isTrue);
      expect(info.amount.drops, '296890496');
      expect(info.amount2.currency, 'TST');
      expect(info.amount2.issuer, 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd');
      expect(info.amount2.value, '25.81656470648473');
      expect(info.assetFrozen, isNull);
      expect(info.asset2Frozen, isFalse);
      expect(info.lpToken.value, '87533.41976112682');
      expect(info.tradingFee, 600);

      final slot = info.auctionSlot!;
      expect(slot.account, 'rJVUeRqDFNs2xqA7ncVE6ZoAhPUoaJJSQm');
      expect(slot.authAccounts, [
        'r3f2WpQMsAd8k4Zoijv2PZ78EYFJ2EdvgV',
        'rnW8FAPgpQgA6VoESnVrUVJHBdq9QAtRZs',
      ]);
      expect(slot.discountedFee, 60);
      expect(slot.expiration, '2023-Jan-26 00:28:40.000000000 UTC');
      expect(slot.price.value, '0');
      expect(slot.timeInterval, 0);

      expect(info.voteSlots, hasLength(1));
      expect(info.voteSlots.single.tradingFee, 600);
      expect(info.voteSlots.single.voteWeight, 9684);

      expect(info.validated, isFalse);
      expect(info.ledgerCurrentIndex, 316725);
      expect(info.ledgerIndex, isNull);
      expect(info.ledgerHash, isNull);
    });

    test('treats the optional fields as absent when the server omits them', () {
      final info = XrplAmmInfo.fromJson({
        'amm': {
          'account': 'rp9E3FN3gNmvePGhYnf414T2TkUuoxu8vM',
          'amount': '1000000',
          'amount2': {
            'currency': 'TST',
            'issuer': 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd',
            'value': '10',
          },
          'lp_token': {
            'currency': '039C99CD9AB0B70B32ECDA51EAAE471625608EA2',
            'issuer': 'rp9E3FN3gNmvePGhYnf414T2TkUuoxu8vM',
            'value': '100',
          },
          'trading_fee': 0,
        },
      });

      expect(info.auctionSlot, isNull);
      expect(info.voteSlots, isEmpty);
      expect(info.assetFrozen, isNull);
      expect(info.asset2Frozen, isNull);
      expect(info.validated, isFalse);
      expect(info.tradingFee, 0);
    });

    test('throws XrplConnectionException when amm is missing', () {
      expect(
        () => XrplAmmInfo.fromJson({'validated': true}),
        throwsA(isA<XrplConnectionException>()),
      );
    });

    test('throws XrplConnectionException when trading_fee is not an int', () {
      expect(
        () => XrplAmmInfo.fromJson({
          'amm': {
            'account': 'rp9E3FN3gNmvePGhYnf414T2TkUuoxu8vM',
            'amount': '1000000',
            'amount2': '2000000',
            'lp_token': '100',
            'trading_fee': '600',
          },
        }),
        throwsA(isA<XrplConnectionException>()),
      );
    });

    test('throws XrplConnectionException when an amount has a wrong shape', () {
      expect(
        () => XrplAmmInfo.fromJson({
          'amm': {
            'account': 'rp9E3FN3gNmvePGhYnf414T2TkUuoxu8vM',
            'amount': 1000000,
            'amount2': '2000000',
            'lp_token': '100',
            'trading_fee': 600,
          },
        }),
        throwsA(isA<XrplConnectionException>()),
      );
    });
  });
}
