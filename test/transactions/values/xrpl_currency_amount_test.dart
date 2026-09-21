import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/transactions/values/xrpl_currency_amount.dart';

void main() {
  group('XrplCurrencyAmount.xrp', () {
    const amount = XrplCurrencyAmount.xrp('6000000');

    test('isXrp is true', () {
      expect(amount.isXrp, isTrue);
    });

    test('toJson returns the plain drops string', () {
      expect(amount.toJson(), '6000000');
    });

    test('currency/issuer/value are all null', () {
      expect(amount.currency, isNull);
      expect(amount.issuer, isNull);
      expect(amount.value, isNull);
    });
  });

  group('XrplCurrencyAmount.issued', () {
    const amount = XrplCurrencyAmount.issued(
      currency: 'GKO',
      issuer: 'ruazs5h1qEsqpke88pcqnaseXdm6od2xc',
      value: '2',
    );

    test('isXrp is false', () {
      expect(amount.isXrp, isFalse);
    });

    test('toJson returns the currency/issuer/value object', () {
      expect(amount.toJson(), {
        'currency': 'GKO',
        'issuer': 'ruazs5h1qEsqpke88pcqnaseXdm6od2xc',
        'value': '2',
      });
    });

    test('drops is null', () {
      expect(amount.drops, isNull);
    });
  });

  group('XrplCurrencyAmount const usage', () {
    test('both constructors can be used as const', () {
      // Compiles as const - confirms the ergonomic const usage this
      // class is designed to preserve, matching XrplPayment's own
      // const-constructor style.
      const xrp = XrplCurrencyAmount.xrp('10');
      const issued = XrplCurrencyAmount.issued(
        currency: 'USD',
        issuer: 'rIssuerAddress...',
        value: '100',
      );
      expect(xrp.isXrp, isTrue);
      expect(issued.isXrp, isFalse);
    });
  });
}
