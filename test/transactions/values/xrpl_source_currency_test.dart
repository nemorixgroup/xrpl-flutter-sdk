import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

void main() {
  group('XrplSourceCurrency', () {
    test('constructs with currency only', () {
      const entry = XrplSourceCurrency(currency: 'USD');

      expect(entry.currency, 'USD');
      expect(entry.issuer, isNull);
    });

    test('constructs with currency and issuer', () {
      const entry = XrplSourceCurrency(
        currency: 'USD',
        issuer: 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
      );

      expect(entry.currency, 'USD');
      expect(entry.issuer, 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B');
    });

    test('copyWith replaces only the given fields', () {
      const entry = XrplSourceCurrency(currency: 'USD', issuer: 'rIssuerOne');

      final updated = entry.copyWith(issuer: 'rIssuerTwo');

      expect(updated.currency, 'USD');
      expect(updated.issuer, 'rIssuerTwo');
    });

    test('toJson omits issuer when not set', () {
      const entry = XrplSourceCurrency(currency: 'USD');

      expect(entry.toJson(), {'currency': 'USD'});
    });

    test('toJson includes issuer when set', () {
      const entry = XrplSourceCurrency(
        currency: 'USD',
        issuer: 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
      );

      expect(entry.toJson(), {
        'currency': 'USD',
        'issuer': 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
      });
    });

    test('two entries with the same fields are equal', () {
      const a = XrplSourceCurrency(currency: 'USD', issuer: 'rIssuer');
      const b = XrplSourceCurrency(currency: 'USD', issuer: 'rIssuer');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two entries with different fields are not equal', () {
      const a = XrplSourceCurrency(currency: 'USD');
      const b = XrplSourceCurrency(currency: 'EUR');

      expect(a, isNot(equals(b)));
    });
  });
}
