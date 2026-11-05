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
const _ammAccount = 'rNJSNwbggDhEBwhRXNeyeY7G2Xy3gxLjYH';
const _lpCurrency = '039C99CD9AB0B70B32ECDA51EAAE471625608EA2';
const _signingPubKey =
    'ED5F5AC8B98974A3CA843326D9B88CEBD0560177B973EE0B149F782911E5E8A9C1';

const _xrp = XrplAsset.xrp();
final _tst = XrplAsset.issued(currency: 'TST', issuer: _issuer);

const _oneXrp = XrplCurrencyAmount.xrp('1000000');

XrplCurrencyAmount _tstAmount(String value) {
  return XrplCurrencyAmount.issued(
    currency: 'TST',
    issuer: _issuer,
    value: value,
  );
}

XrplCurrencyAmount _lpAmount(String value) {
  return XrplCurrencyAmount.issued(
    currency: _lpCurrency,
    issuer: _ammAccount,
    value: value,
  );
}

void main() {
  group('XrplAmmWithdraw flags', () {
    test('match the values in the official specification', () {
      expect(XrplAmmWithdraw.tfLpToken, 0x00010000);
      expect(XrplAmmWithdraw.tfWithdrawAll, 0x00020000);
      expect(XrplAmmWithdraw.tfOneAssetWithdrawAll, 0x00040000);
      expect(XrplAmmWithdraw.tfSingleAsset, 0x00080000);
      expect(XrplAmmWithdraw.tfTwoAsset, 0x00100000);
      expect(XrplAmmWithdraw.tfOneAssetLpToken, 0x00200000);
      expect(XrplAmmWithdraw.tfLimitLpToken, 0x00400000);
    });
  });

  group('XrplAmmWithdraw toJson', () {
    test('lpToken sends only LPTokenIn and the tfLPToken flag', () {
      final withdraw = XrplAmmWithdraw.lpToken(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        lpTokenIn: _lpAmount('100'),
      );

      expect(withdraw.toJson(), {
        'TransactionType': 'AMMWithdraw',
        'Account': _account,
        'Asset': {'currency': 'XRP'},
        'Asset2': {'currency': 'TST', 'issuer': _issuer},
        'LPTokenIn': {
          'currency': _lpCurrency,
          'issuer': _ammAccount,
          'value': '100',
        },
        'Flags': 0x00010000,
      });
    });

    test('withdrawAll sends no amounts, only the tfWithdrawAll flag', () {
      final withdraw = XrplAmmWithdraw.withdrawAll(
        account: _account,
        asset: _xrp,
        asset2: _tst,
      );

      expect(withdraw.toJson(), {
        'TransactionType': 'AMMWithdraw',
        'Account': _account,
        'Asset': {'currency': 'XRP'},
        'Asset2': {'currency': 'TST', 'issuer': _issuer},
        'Flags': 0x00020000,
      });
    });

    test(
        'oneAssetWithdrawAll sends only Amount and the '
        'tfOneAssetWithdrawAll flag', () {
      final withdraw = XrplAmmWithdraw.oneAssetWithdrawAll(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        amount: _oneXrp,
      );

      expect(withdraw.flags, XrplAmmWithdraw.tfOneAssetWithdrawAll);
      expect(withdraw.toJson()['Amount'], '1000000');
      expect(withdraw.toJson().containsKey('LPTokenIn'), isFalse);
      expect(withdraw.toJson().containsKey('EPrice'), isFalse);
    });

    test('singleAsset sends only Amount and the tfSingleAsset flag', () {
      final withdraw = XrplAmmWithdraw.singleAsset(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        amount: _oneXrp,
      );

      expect(withdraw.toJson(), {
        'TransactionType': 'AMMWithdraw',
        'Account': _account,
        'Asset': {'currency': 'XRP'},
        'Asset2': {'currency': 'TST', 'issuer': _issuer},
        'Amount': '1000000',
        'Flags': 0x00080000,
      });
    });

    test('twoAsset sends Amount and Amount2 and the tfTwoAsset flag', () {
      final withdraw = XrplAmmWithdraw.twoAsset(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        amount: _oneXrp,
        amount2: _tstAmount('10'),
      );

      expect(withdraw.toJson(), {
        'TransactionType': 'AMMWithdraw',
        'Account': _account,
        'Asset': {'currency': 'XRP'},
        'Asset2': {'currency': 'TST', 'issuer': _issuer},
        'Amount': '1000000',
        'Amount2': {'currency': 'TST', 'issuer': _issuer, 'value': '10'},
        'Flags': 0x00100000,
      });
    });

    test(
        'oneAssetLpToken sends Amount and LPTokenIn and the '
        'tfOneAssetLPToken flag', () {
      final withdraw = XrplAmmWithdraw.oneAssetLpToken(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        amount: _oneXrp,
        lpTokenIn: _lpAmount('100'),
      );

      expect(withdraw.flags, XrplAmmWithdraw.tfOneAssetLpToken);
      expect(withdraw.toJson()['Amount'], '1000000');
      expect(withdraw.toJson()['LPTokenIn'], isA<Map<String, dynamic>>());
      expect(withdraw.toJson().containsKey('Amount2'), isFalse);
      expect(withdraw.toJson().containsKey('EPrice'), isFalse);
    });

    test('limitLpToken sends Amount and EPrice and the tfLimitLPToken flag',
        () {
      final withdraw = XrplAmmWithdraw.limitLpToken(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        amount: _oneXrp,
        ePrice: const XrplCurrencyAmount.xrp('100000'),
      );

      expect(withdraw.flags, XrplAmmWithdraw.tfLimitLpToken);
      expect(withdraw.toJson()['Amount'], '1000000');
      expect(withdraw.toJson()['EPrice'], '100000');
      expect(withdraw.toJson().containsKey('LPTokenIn'), isFalse);
    });

    test('sequence, fee and lastLedgerSequence are sent only when set', () {
      final bare = XrplAmmWithdraw.singleAsset(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        amount: _oneXrp,
      ).toJson();
      expect(bare.containsKey('Sequence'), isFalse);
      expect(bare.containsKey('Fee'), isFalse);
      expect(bare.containsKey('LastLedgerSequence'), isFalse);

      final filled = XrplAmmWithdraw.singleAsset(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        amount: _oneXrp,
        sequence: 9,
        fee: '10',
        lastLedgerSequence: 102,
      ).toJson();
      expect(filled['Sequence'], 9);
      expect(filled['Fee'], '10');
      expect(filled['LastLedgerSequence'], 102);
    });
  });

  group('XrplAmmWithdraw copyWith', () {
    test('fills sequence, fee and lastLedgerSequence and keeps the rest', () {
      final original = XrplAmmWithdraw.oneAssetLpToken(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        amount: _oneXrp,
        lpTokenIn: _lpAmount('100'),
      );

      final copy = original.copyWith(
        sequence: 9,
        fee: '10',
        lastLedgerSequence: 102,
      );

      expect(copy.sequence, 9);
      expect(copy.fee, '10');
      expect(copy.lastLedgerSequence, 102);
      expect(copy.flags, original.flags);
      expect(copy.asset, original.asset);
      expect(copy.asset2, original.asset2);
      expect(copy.toJson()['Amount'], original.toJson()['Amount']);
      expect(copy.toJson()['LPTokenIn'], original.toJson()['LPTokenIn']);
    });

    test('does not mutate the original', () {
      final original = XrplAmmWithdraw.singleAsset(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        amount: _oneXrp,
      )..copyWith(sequence: 9, fee: '10', lastLedgerSequence: 102);

      expect(original.sequence, isNull);
      expect(original.fee, isNull);
      expect(original.lastLedgerSequence, isNull);
    });
  });

  group('XrplAmmWithdraw validation', () {
    test('rejects a pool whose two assets are the same', () {
      expect(
        () => XrplAmmWithdraw.withdrawAll(
          account: _account,
          asset: _tst,
          asset2: _tst,
        ),
        throwsArgumentError,
      );
    });

    test('rejects an XRP amount of zero drops', () {
      expect(
        () => XrplAmmWithdraw.singleAsset(
          account: _account,
          asset: _xrp,
          asset2: _tst,
          amount: const XrplCurrencyAmount.xrp('0'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects an issued amount that is zero or negative', () {
      expect(
        () => XrplAmmWithdraw.singleAsset(
          account: _account,
          asset: _xrp,
          asset2: _tst,
          amount: _tstAmount('0'),
        ),
        throwsArgumentError,
      );
      expect(
        () => XrplAmmWithdraw.singleAsset(
          account: _account,
          asset: _xrp,
          asset2: _tst,
          amount: _tstAmount('-5'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects an amount that is not one of the pool assets', () {
      expect(
        () => XrplAmmWithdraw.singleAsset(
          account: _account,
          asset: _xrp,
          asset2: _tst,
          amount: const XrplCurrencyAmount.issued(
            currency: 'TST',
            issuer: _otherIssuer, // same code, different issuer
            value: '10',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rejects an amount2 that is not one of the pool assets', () {
      expect(
        () => XrplAmmWithdraw.twoAsset(
          account: _account,
          asset: _xrp,
          asset2: _tst,
          amount: _oneXrp,
          amount2: const XrplCurrencyAmount.issued(
            currency: 'USD',
            issuer: _otherIssuer,
            value: '10',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rejects amount and amount2 being the same asset', () {
      expect(
        () => XrplAmmWithdraw.twoAsset(
          account: _account,
          asset: _xrp,
          asset2: _tst,
          amount: _oneXrp,
          amount2: const XrplCurrencyAmount.xrp('2000000'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects an lpTokenIn that is XRP', () {
      expect(
        () => XrplAmmWithdraw.lpToken(
          account: _account,
          asset: _xrp,
          asset2: _tst,
          lpTokenIn: _oneXrp,
        ),
        throwsArgumentError,
      );
    });

    test('rejects an lpTokenIn of zero', () {
      expect(
        () => XrplAmmWithdraw.lpToken(
          account: _account,
          asset: _xrp,
          asset2: _tst,
          lpTokenIn: _lpAmount('0'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects an ePrice of zero', () {
      expect(
        () => XrplAmmWithdraw.limitLpToken(
          account: _account,
          asset: _xrp,
          asset2: _tst,
          amount: _oneXrp,
          ePrice: const XrplCurrencyAmount.xrp('0'),
        ),
        throwsArgumentError,
      );
    });

    test('oneAssetWithdrawAll accepts an Amount of zero', () {
      // The official page says the specified amount can be 0, meaning
      // the transaction succeeds if it withdraws any positive amount.
      final xrpZero = XrplAmmWithdraw.oneAssetWithdrawAll(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        amount: const XrplCurrencyAmount.xrp('0'),
      );
      final tstZero = XrplAmmWithdraw.oneAssetWithdrawAll(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        amount: _tstAmount('0'),
      );

      expect(xrpZero.toJson()['Amount'], '0');
      expect(tstZero.flags, XrplAmmWithdraw.tfOneAssetWithdrawAll);
    });

    test('oneAssetWithdrawAll still rejects a negative Amount', () {
      expect(
        () => XrplAmmWithdraw.oneAssetWithdrawAll(
          account: _account,
          asset: _xrp,
          asset2: _tst,
          amount: _tstAmount('-1'),
        ),
        throwsArgumentError,
      );
    });

    test('oneAssetWithdrawAll still requires a pool asset', () {
      expect(
        () => XrplAmmWithdraw.oneAssetWithdrawAll(
          account: _account,
          asset: _xrp,
          asset2: _tst,
          amount: const XrplCurrencyAmount.issued(
            currency: 'USD',
            issuer: _otherIssuer,
            value: '0',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('accepts a pool of two issued assets', () {
      final usd = XrplAsset.issued(currency: 'USD', issuer: _otherIssuer);

      final withdraw = XrplAmmWithdraw.twoAsset(
        account: _account,
        asset: usd,
        asset2: _tst,
        amount: const XrplCurrencyAmount.issued(
          currency: 'USD',
          issuer: _otherIssuer,
          value: '1.5',
        ),
        amount2: _tstAmount('10'),
      );

      expect(withdraw.flags, XrplAmmWithdraw.tfTwoAsset);
    });
  });

  group('XrplAmmWithdraw serialization', () {
    // Every expected hex below was produced by the official xrpl-py
    // binary codec, not by this SDK. They are the same vectors the
    // serializer tests use, here reached through the model.
    Uint8List serialize(XrplAmmWithdraw withdraw) {
      return XrplTransactionSerializer.serialize({
        ...withdraw.toJson(),
        'SigningPubKey': _signingPubKey,
      });
    }

    test('a singleAsset withdrawal serializes like the xrpl-py vector', () {
      final withdraw = XrplAmmWithdraw.singleAsset(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        amount: _oneXrp,
        sequence: 9,
        fee: '10',
        lastLedgerSequence: 102,
      );

      expect(
        serialize(withdraw),
        _hexToBytes(
          '12002522000800002400000009201b000000666140000000000f424'
          '068400000000000000a7321ed5f5ac8b98974a3ca843326d9b88ceb'
          'd0560177b973ee0b149f782911e5e8a9c18114f667b0ca50cc7709a'
          '220b0561b85e53a48461fa803180000000000000000000000000000'
          '0000000000000418000000000000000000000000545354000000000'
          '0f2f97c4301c80d60f86653a319aa7f302c70b83b',
        ),
      );
    });

    test('an lpToken withdrawal serializes like the xrpl-py vector', () {
      final withdraw = XrplAmmWithdraw.lpToken(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        lpTokenIn: _lpAmount('100'),
        sequence: 9,
        fee: '10',
        lastLedgerSequence: 102,
      );

      expect(
        serialize(withdraw),
        _hexToBytes(
          '12002522000100002400000009201b0000006668400000000000000'
          'a601ad5038d7ea4c68000039c99cd9ab0b70b32ecda51eaae471625'
          '608ea291e5c3d526d6af03e629efbc0a095613116ea1007321ed5f5'
          'ac8b98974a3ca843326d9b88cebd0560177b973ee0b149f782911e5'
          'e8a9c18114f667b0ca50cc7709a220b0561b85e53a48461fa803180'
          '0000000000000000000000000000000000000000418000000000000'
          '0000000000005453540000000000f2f97c4301c80d60f86653a319a'
          'a7f302c70b83b',
        ),
      );
    });

    test('a withdrawAll serializes like the xrpl-py vector', () {
      final withdraw = XrplAmmWithdraw.withdrawAll(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        sequence: 9,
        fee: '10',
        lastLedgerSequence: 102,
      );

      expect(
        serialize(withdraw),
        _hexToBytes(
          '12002522000200002400000009201b0000006668400000000000000'
          'a7321ed5f5ac8b98974a3ca843326d9b88cebd0560177b973ee0b14'
          '9f782911e5e8a9c18114f667b0ca50cc7709a220b0561b85e53a484'
          '61fa803180000000000000000000000000000000000000000041800'
          '00000000000000000000005453540000000000f2f97c4301c80d60f'
          '86653a319aa7f302c70b83b',
        ),
      );
    });
  });
}
