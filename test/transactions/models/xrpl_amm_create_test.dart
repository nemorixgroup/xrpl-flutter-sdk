import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/transactions/binary/xrpl_transaction_serializer.dart';
import 'package:xrpl_flutter_sdk/src/transactions/models/xrpl_amm_create.dart';
import 'package:xrpl_flutter_sdk/src/transactions/values/xrpl_currency_amount.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_owner_reserve_cost_transaction.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_transaction.dart';

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return result;
}

void main() {
  const account = 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe';
  const tenXrp = XrplCurrencyAmount.xrp('10000000');
  const tst = XrplCurrencyAmount.issued(
    currency: 'TST',
    issuer: 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd',
    value: '25',
  );

  group('XrplAmmCreate', () {
    test('keeps the fields it was given', () {
      final tx = XrplAmmCreate(
        account: account,
        amount: tenXrp,
        amount2: tst,
        tradingFee: 500,
      );

      expect(tx.account, account);
      expect(tx.amount, tenXrp);
      expect(tx.amount2, tst);
      expect(tx.tradingFee, 500);
      expect(tx.sequence, isNull);
      expect(tx.fee, isNull);
      expect(tx.lastLedgerSequence, isNull);
    });

    test('is an XrplTransaction that pays the owner reserve as its cost', () {
      final tx = XrplAmmCreate(
        account: account,
        amount: tenXrp,
        amount2: tst,
        tradingFee: 500,
      );

      expect(tx, isA<XrplTransaction>());
      expect(tx, isA<XrplOwnerReserveCostTransaction>());
    });

    test('toJson includes the required fields and omits unset ones', () {
      final tx = XrplAmmCreate(
        account: account,
        amount: tenXrp,
        amount2: tst,
        tradingFee: 500,
      );

      expect(tx.toJson(), {
        'TransactionType': 'AMMCreate',
        'Account': account,
        'Amount': '10000000',
        'Amount2': {
          'currency': 'TST',
          'issuer': 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd',
          'value': '25',
        },
        'TradingFee': 500,
      });
    });

    test('toJson includes sequence, fee and lastLedgerSequence when set', () {
      final tx = XrplAmmCreate(
        account: account,
        amount: tenXrp,
        amount2: tst,
        tradingFee: 500,
        sequence: 7,
        fee: '200000',
        lastLedgerSequence: 100,
      );

      final json = tx.toJson();

      expect(json['Sequence'], 7);
      expect(json['Fee'], '200000');
      expect(json['LastLedgerSequence'], 100);
    });

    test('copyWith replaces only sequence, fee and lastLedgerSequence', () {
      final tx = XrplAmmCreate(
        account: account,
        amount: tenXrp,
        amount2: tst,
        tradingFee: 500,
      );

      final filled = tx.copyWith(
        sequence: 7,
        fee: '200000',
        lastLedgerSequence: 100,
      );

      expect(filled, isA<XrplAmmCreate>());
      expect(filled.sequence, 7);
      expect(filled.fee, '200000');
      expect(filled.lastLedgerSequence, 100);
      expect(filled.account, account);
      expect(filled.amount, tenXrp);
      expect(filled.amount2, tst);
      expect(filled.tradingFee, 500);
      // The original is not mutated.
      expect(tx.sequence, isNull);
    });

    test('toJson serializes to the same bytes as the xrpl-py codec', () {
      final tx = XrplAmmCreate(
        account: account,
        amount: tenXrp,
        amount2: tst,
        tradingFee: 500,
        sequence: 7,
        fee: '200000',
        lastLedgerSequence: 100,
      );

      final json = tx.toJson()
        ..['SigningPubKey'] = 'ED5F5AC8B98974A3CA843326D9B88CEBD0560177'
            'B973EE0B149F782911E5E8A9C1';

      expect(
        XrplTransactionSerializer.serialize(json),
        _hexToBytes(
          '1200231501f42400000007201b0000006461400000000098968068'
          '4000000000030d406bd4c8e1bc9bf0400000000000000000000000'
          '00005453540000000000f2f97c4301c80d60f86653a319aa7f302c'
          '70b83b7321ed5f5ac8b98974a3ca843326d9b88cebd0560177b973'
          'ee0b149f782911e5e8a9c18114f667b0ca50cc7709a220b0561b85'
          'e53a48461fa8',
        ),
      );
    });
  });

  group('XrplAmmCreate validation', () {
    test('accepts the TradingFee limits 0 and 1000', () {
      expect(
        () => XrplAmmCreate(
          account: account,
          amount: tenXrp,
          amount2: tst,
          tradingFee: 0,
        ),
        returnsNormally,
      );
      expect(
        () => XrplAmmCreate(
          account: account,
          amount: tenXrp,
          amount2: tst,
          tradingFee: 1000,
        ),
        returnsNormally,
      );
    });

    test('throws ArgumentError when TradingFee is below 0', () {
      expect(
        () => XrplAmmCreate(
          account: account,
          amount: tenXrp,
          amount2: tst,
          tradingFee: -1,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when TradingFee is above 1000', () {
      expect(
        () => XrplAmmCreate(
          account: account,
          amount: tenXrp,
          amount2: tst,
          tradingFee: 1001,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when both amounts are XRP', () {
      expect(
        () => XrplAmmCreate(
          account: account,
          amount: tenXrp,
          amount2: const XrplCurrencyAmount.xrp('5000000'),
          tradingFee: 500,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when both amounts are the same token', () {
      expect(
        () => XrplAmmCreate(
          account: account,
          amount: tst,
          amount2: const XrplCurrencyAmount.issued(
            currency: 'TST',
            issuer: 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd',
            value: '10',
          ),
          tradingFee: 500,
        ),
        throwsArgumentError,
      );
    });

    test('accepts the same currency code with different issuers', () {
      expect(
        () => XrplAmmCreate(
          account: account,
          amount: tst,
          amount2: const XrplCurrencyAmount.issued(
            currency: 'TST',
            issuer: 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
            value: '10',
          ),
          tradingFee: 500,
        ),
        returnsNormally,
      );
    });

    test('accepts two different tokens', () {
      expect(
        () => XrplAmmCreate(
          account: account,
          amount: tst,
          amount2: const XrplCurrencyAmount.issued(
            currency: 'USD',
            issuer: 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
            value: '1.5',
          ),
          tradingFee: 500,
        ),
        returnsNormally,
      );
    });

    test('throws ArgumentError when an XRP amount is zero', () {
      expect(
        () => XrplAmmCreate(
          account: account,
          amount: const XrplCurrencyAmount.xrp('0'),
          amount2: tst,
          tradingFee: 500,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when an XRP amount is not a number', () {
      expect(
        () => XrplAmmCreate(
          account: account,
          amount: const XrplCurrencyAmount.xrp('abc'),
          amount2: tst,
          tradingFee: 500,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when a token amount is zero', () {
      expect(
        () => XrplAmmCreate(
          account: account,
          amount: tenXrp,
          amount2: const XrplCurrencyAmount.issued(
            currency: 'TST',
            issuer: 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd',
            value: '0',
          ),
          tradingFee: 500,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when a token amount is negative', () {
      expect(
        () => XrplAmmCreate(
          account: account,
          amount: tenXrp,
          amount2: const XrplCurrencyAmount.issued(
            currency: 'TST',
            issuer: 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd',
            value: '-1',
          ),
          tradingFee: 500,
        ),
        throwsArgumentError,
      );
    });

    test('copyWith still validates, since it rebuilds the transaction', () {
      final tx = XrplAmmCreate(
        account: account,
        amount: tenXrp,
        amount2: tst,
        tradingFee: 500,
      );

      expect(tx.copyWith(sequence: 1), isA<XrplAmmCreate>());
    });
  });
}
