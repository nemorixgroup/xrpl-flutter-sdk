import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return result;
}

const _account = 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe';
const _issuer = 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd';
const _otherIssuer = 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B';
const _signingPubKey =
    'ED5F5AC8B98974A3CA843326D9B88CEBD0560177B973EE0B149F782911E5E8A9C1';

const _xrp = XrplAsset.xrp();
final _tst = XrplAsset.issued(currency: 'TST', issuer: _issuer);

void main() {
  group('XrplAmmVote toJson', () {
    test('sends the pool assets and the proposed TradingFee', () {
      final vote = XrplAmmVote(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        tradingFee: 500,
      );

      expect(vote.toJson(), {
        'TransactionType': 'AMMVote',
        'Account': _account,
        'Asset': {'currency': 'XRP'},
        'Asset2': {'currency': 'TST', 'issuer': _issuer},
        'TradingFee': 500,
      });
    });

    test('sends no Flags, because AMMVote has none', () {
      final json = XrplAmmVote(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        tradingFee: 500,
      ).toJson();

      expect(json.containsKey('Flags'), isFalse);
    });

    test('a TradingFee of 0 is sent, not omitted', () {
      final json = XrplAmmVote(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        tradingFee: 0,
      ).toJson();

      expect(json['TradingFee'], 0);
    });

    test('sequence, fee and lastLedgerSequence are sent only when set', () {
      final bare = XrplAmmVote(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        tradingFee: 500,
      ).toJson();
      expect(bare.containsKey('Sequence'), isFalse);
      expect(bare.containsKey('Fee'), isFalse);
      expect(bare.containsKey('LastLedgerSequence'), isFalse);

      final filled = XrplAmmVote(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        tradingFee: 500,
        sequence: 9,
        fee: '10',
        lastLedgerSequence: 102,
      ).toJson();
      expect(filled['Sequence'], 9);
      expect(filled['Fee'], '10');
      expect(filled['LastLedgerSequence'], 102);
    });
  });

  group('XrplAmmVote copyWith', () {
    test('fills sequence, fee and lastLedgerSequence and keeps the rest', () {
      final original = XrplAmmVote(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        tradingFee: 500,
      );

      final copy = original.copyWith(
        sequence: 9,
        fee: '10',
        lastLedgerSequence: 102,
      );

      expect(copy.sequence, 9);
      expect(copy.fee, '10');
      expect(copy.lastLedgerSequence, 102);
      expect(copy.account, original.account);
      expect(copy.asset, original.asset);
      expect(copy.asset2, original.asset2);
      expect(copy.tradingFee, original.tradingFee);
    });

    test('does not mutate the original', () {
      final original = XrplAmmVote(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        tradingFee: 500,
      )..copyWith(sequence: 9, fee: '10', lastLedgerSequence: 102);

      expect(original.sequence, isNull);
      expect(original.fee, isNull);
      expect(original.lastLedgerSequence, isNull);
    });
  });

  group('XrplAmmVote validation', () {
    test('maxTradingFee is 1000, a 1% fee', () {
      expect(XrplAmmVote.maxTradingFee, 1000);
    });

    test('rejects a pool whose two assets are the same', () {
      expect(
        () => XrplAmmVote(
          account: _account,
          asset: _tst,
          asset2: _tst,
          tradingFee: 500,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative TradingFee', () {
      expect(
        () => XrplAmmVote(
          account: _account,
          asset: _xrp,
          asset2: _tst,
          tradingFee: -1,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a TradingFee above the maximum', () {
      expect(
        () => XrplAmmVote(
          account: _account,
          asset: _xrp,
          asset2: _tst,
          tradingFee: 1001,
        ),
        throwsArgumentError,
      );
    });

    test('accepts the limits 0 and 1000', () {
      for (final fee in [0, 1000]) {
        final vote = XrplAmmVote(
          account: _account,
          asset: _xrp,
          asset2: _tst,
          tradingFee: fee,
        );
        expect(vote.tradingFee, fee);
      }
    });

    test('accepts a pool of two issued assets', () {
      final usd = XrplAsset.issued(currency: 'USD', issuer: _otherIssuer);

      final vote = XrplAmmVote(
        account: _account,
        asset: usd,
        asset2: _tst,
        tradingFee: 300,
      );

      expect(vote.toJson()['Asset'], {
        'currency': 'USD',
        'issuer': _otherIssuer,
      });
    });
  });

  group('XrplAmmVote serialization', () {
    // Every expected hex below was produced by the official xrpl-py
    // binary codec, not by this SDK. They are the same vectors the
    // serializer tests use, here reached through the model.
    Uint8List serialize(XrplAmmVote vote) {
      return XrplTransactionSerializer.serialize({
        ...vote.toJson(),
        'SigningPubKey': _signingPubKey,
      });
    }

    test('a vote for 500 serializes like the xrpl-py vector', () {
      final vote = XrplAmmVote(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        tradingFee: 500,
        sequence: 9,
        fee: '10',
        lastLedgerSequence: 102,
      );

      expect(
        serialize(vote),
        _hexToBytes(
          '1200261501f42400000009201b0000006668400000000000000a732'
          '1ed5f5ac8b98974a3ca843326d9b88cebd0560177b973ee0b149f78'
          '2911e5e8a9c18114f667b0ca50cc7709a220b0561b85e53a48461fa'
          '8031800000000000000000000000000000000000000000418000000'
          '0000000000000000005453540000000000f2f97c4301c80d60f8665'
          '3a319aa7f302c70b83b',
        ),
      );
    });

    test('a vote for 0 serializes like the xrpl-py vector', () {
      final vote = XrplAmmVote(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        tradingFee: 0,
        sequence: 9,
        fee: '10',
        lastLedgerSequence: 102,
      );

      expect(
        serialize(vote),
        _hexToBytes(
          '1200261500002400000009201b0000006668400000000000000a732'
          '1ed5f5ac8b98974a3ca843326d9b88cebd0560177b973ee0b149f78'
          '2911e5e8a9c18114f667b0ca50cc7709a220b0561b85e53a48461fa'
          '8031800000000000000000000000000000000000000000418000000'
          '0000000000000000005453540000000000f2f97c4301c80d60f8665'
          '3a319aa7f302c70b83b',
        ),
      );
    });
  });
}
