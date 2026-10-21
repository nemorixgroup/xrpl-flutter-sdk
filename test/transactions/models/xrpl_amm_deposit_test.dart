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
  group('XrplAmmDeposit flags', () {
    test('match the values in the official specification', () {
      expect(XrplAmmDeposit.tfLpToken, 0x00010000);
      expect(XrplAmmDeposit.tfSingleAsset, 0x00080000);
      expect(XrplAmmDeposit.tfTwoAsset, 0x00100000);
      expect(XrplAmmDeposit.tfOneAssetLpToken, 0x00200000);
      expect(XrplAmmDeposit.tfLimitLpToken, 0x00400000);
      expect(XrplAmmDeposit.tfTwoAssetIfEmpty, 0x00800000);
    });
  });

  group('XrplAmmDeposit toJson', () {
    test('lpToken sends only LPTokenOut and the tfLPToken flag', () {
      final deposit = XrplAmmDeposit.lpToken(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        lpTokenOut: _lpAmount('100'),
      );

      expect(deposit.toJson(), {
        'TransactionType': 'AMMDeposit',
        'Account': _account,
        'Asset': {'currency': 'XRP'},
        'Asset2': {'currency': 'TST', 'issuer': _issuer},
        'LPTokenOut': {
          'currency': _lpCurrency,
          'issuer': _ammAccount,
          'value': '100',
        },
        'Flags': 0x00010000,
      });
    });

    test('twoAsset sends Amount and Amount2 and the tfTwoAsset flag', () {
      final deposit = XrplAmmDeposit.twoAsset(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        amount: _oneXrp,
        amount2: _tstAmount('10'),
      );

      expect(deposit.toJson(), {
        'TransactionType': 'AMMDeposit',
        'Account': _account,
        'Asset': {'currency': 'XRP'},
        'Asset2': {'currency': 'TST', 'issuer': _issuer},
        'Amount': '1000000',
        'Amount2': {'currency': 'TST', 'issuer': _issuer, 'value': '10'},
        'Flags': 0x00100000,
      });
    });

    test(
        'twoAssetIfEmpty sends Amount and Amount2 and the '
        'tfTwoAssetIfEmpty flag', () {
      final deposit = XrplAmmDeposit.twoAssetIfEmpty(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        amount: _oneXrp,
        amount2: _tstAmount('10'),
      );

      expect(deposit.flags, XrplAmmDeposit.tfTwoAssetIfEmpty);
      expect(deposit.toJson()['Amount'], '1000000');
      expect(deposit.toJson().containsKey('Amount2'), isTrue);
      expect(deposit.toJson().containsKey('LPTokenOut'), isFalse);
      expect(deposit.toJson().containsKey('EPrice'), isFalse);
    });

    test('singleAsset sends only Amount and the tfSingleAsset flag', () {
      final deposit = XrplAmmDeposit.singleAsset(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        amount: _oneXrp,
      );

      expect(deposit.toJson(), {
        'TransactionType': 'AMMDeposit',
        'Account': _account,
        'Asset': {'currency': 'XRP'},
        'Asset2': {'currency': 'TST', 'issuer': _issuer},
        'Amount': '1000000',
        'Flags': 0x00080000,
      });
    });

    test(
        'oneAssetLpToken sends Amount and LPTokenOut and the '
        'tfOneAssetLPToken flag', () {
      final deposit = XrplAmmDeposit.oneAssetLpToken(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        amount: _oneXrp,
        lpTokenOut: _lpAmount('100'),
      );

      expect(deposit.flags, XrplAmmDeposit.tfOneAssetLpToken);
      expect(deposit.toJson()['Amount'], '1000000');
      expect(deposit.toJson()['LPTokenOut'], isA<Map<String, dynamic>>());
      expect(deposit.toJson().containsKey('Amount2'), isFalse);
      expect(deposit.toJson().containsKey('EPrice'), isFalse);
    });

    test('limitLpToken sends Amount and EPrice and the tfLimitLPToken flag',
        () {
      final deposit = XrplAmmDeposit.limitLpToken(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        amount: _oneXrp,
        ePrice: const XrplCurrencyAmount.xrp('100000'),
      );

      expect(deposit.flags, XrplAmmDeposit.tfLimitLpToken);
      expect(deposit.toJson()['Amount'], '1000000');
      expect(deposit.toJson()['EPrice'], '100000');
      expect(deposit.toJson().containsKey('LPTokenOut'), isFalse);
    });

    test('sequence, fee and lastLedgerSequence are sent only when set', () {
      final bare = XrplAmmDeposit.singleAsset(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        amount: _oneXrp,
      ).toJson();
      expect(bare.containsKey('Sequence'), isFalse);
      expect(bare.containsKey('Fee'), isFalse);
      expect(bare.containsKey('LastLedgerSequence'), isFalse);

      final filled = XrplAmmDeposit.singleAsset(
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

  group('XrplAmmDeposit copyWith', () {
    test('fills sequence, fee and lastLedgerSequence and keeps the rest', () {
      final original = XrplAmmDeposit.oneAssetLpToken(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        amount: _oneXrp,
        lpTokenOut: _lpAmount('100'),
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
      expect(copy.toJson()['LPTokenOut'], original.toJson()['LPTokenOut']);
    });

    test('does not mutate the original', () {
      final original = XrplAmmDeposit.singleAsset(
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

  group('XrplAmmDeposit validation', () {
    test('rejects a pool whose two assets are the same', () {
      expect(
        () => XrplAmmDeposit.singleAsset(
          account: _account,
          asset: _tst,
          asset2: _tst,
          amount: _tstAmount('10'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects an XRP amount of zero drops', () {
      expect(
        () => XrplAmmDeposit.singleAsset(
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
        () => XrplAmmDeposit.singleAsset(
          account: _account,
          asset: _xrp,
          asset2: _tst,
          amount: _tstAmount('0'),
        ),
        throwsArgumentError,
      );
      expect(
        () => XrplAmmDeposit.singleAsset(
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
        () => XrplAmmDeposit.singleAsset(
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
        () => XrplAmmDeposit.twoAsset(
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
        () => XrplAmmDeposit.twoAsset(
          account: _account,
          asset: _xrp,
          asset2: _tst,
          amount: _oneXrp,
          amount2: const XrplCurrencyAmount.xrp('2000000'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects an lpTokenOut that is XRP', () {
      expect(
        () => XrplAmmDeposit.lpToken(
          account: _account,
          asset: _xrp,
          asset2: _tst,
          lpTokenOut: _oneXrp,
        ),
        throwsArgumentError,
      );
    });

    test('rejects an lpTokenOut of zero', () {
      expect(
        () => XrplAmmDeposit.lpToken(
          account: _account,
          asset: _xrp,
          asset2: _tst,
          lpTokenOut: _lpAmount('0'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects an ePrice of zero', () {
      expect(
        () => XrplAmmDeposit.limitLpToken(
          account: _account,
          asset: _xrp,
          asset2: _tst,
          amount: _oneXrp,
          ePrice: const XrplCurrencyAmount.xrp('0'),
        ),
        throwsArgumentError,
      );
    });

    test('accepts a pool of two issued assets', () {
      final usd = XrplAsset.issued(currency: 'USD', issuer: _otherIssuer);

      final deposit = XrplAmmDeposit.twoAsset(
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

      expect(deposit.flags, XrplAmmDeposit.tfTwoAsset);
    });
  });

  group('XrplAmmDeposit serialization', () {
    // Both expected hex values below were produced by the official
    // xrpl-py binary codec, not by this SDK. They are the same vectors
    // the serializer tests use, here reached through the model.
    test('a singleAsset deposit serializes like the xrpl-py vector', () {
      final deposit = XrplAmmDeposit.singleAsset(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        amount: _oneXrp,
        sequence: 9,
        fee: '10',
        lastLedgerSequence: 102,
      );

      final serialized = XrplTransactionSerializer.serialize({
        ...deposit.toJson(),
        'SigningPubKey': _signingPubKey,
      });

      expect(
        serialized,
        _hexToBytes(
          '12002422000800002400000009201b000000666140000000000f42'
          '4068400000000000000a7321ed5f5ac8b98974a3ca843326d9b88c'
          'ebd0560177b973ee0b149f782911e5e8a9c18114f667b0ca50cc77'
          '09a220b0561b85e53a48461fa80318000000000000000000000000'
          '000000000000000004180000000000000000000000005453540000'
          '000000f2f97c4301c80d60f86653a319aa7f302c70b83b',
        ),
      );
    });

    test('an lpToken deposit serializes like the xrpl-py vector', () {
      final deposit = XrplAmmDeposit.lpToken(
        account: _account,
        asset: _xrp,
        asset2: _tst,
        lpTokenOut: _lpAmount('100'),
        sequence: 9,
        fee: '10',
        lastLedgerSequence: 102,
      );

      final serialized = XrplTransactionSerializer.serialize({
        ...deposit.toJson(),
        'SigningPubKey': _signingPubKey,
      });

      expect(
        serialized,
        _hexToBytes(
          '12002422000100002400000009201b000000666840000000000000'
          '0a6019d5038d7ea4c68000039c99cd9ab0b70b32ecda51eaae4716'
          '25608ea291e5c3d526d6af03e629efbc0a095613116ea1007321ed'
          '5f5ac8b98974a3ca843326d9b88cebd0560177b973ee0b149f7829'
          '11e5e8a9c18114f667b0ca50cc7709a220b0561b85e53a48461fa8'
          '031800000000000000000000000000000000000000000418000000'
          '0000000000000000005453540000000000f2f97c4301c80d60f866'
          '53a319aa7f302c70b83b',
        ),
      );
    });
  });
}
