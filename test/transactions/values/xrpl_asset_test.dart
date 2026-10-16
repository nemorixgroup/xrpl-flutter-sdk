import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/transactions/values/xrpl_asset.dart';

void main() {
  group('XrplAsset', () {
    const issuer = 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd';

    test('xrp() has currency XRP and no issuer', () {
      const asset = XrplAsset.xrp();

      expect(asset.currency, 'XRP');
      expect(asset.issuer, isNull);
      expect(asset.isXrp, isTrue);
    });

    test('issued() keeps currency and issuer', () {
      final asset = XrplAsset.issued(currency: 'TST', issuer: issuer);

      expect(asset.currency, 'TST');
      expect(asset.issuer, issuer);
      expect(asset.isXrp, isFalse);
    });

    test('issued() throws ArgumentError when currency is empty', () {
      expect(
        () => XrplAsset.issued(currency: '', issuer: issuer),
        throwsArgumentError,
      );
    });

    test('issued() throws ArgumentError when currency is XRP', () {
      expect(
        () => XrplAsset.issued(currency: 'XRP', issuer: issuer),
        throwsArgumentError,
      );
    });

    test('issued() throws ArgumentError when issuer is empty', () {
      expect(
        () => XrplAsset.issued(currency: 'TST', issuer: ''),
        throwsArgumentError,
      );
    });

    test('toJson of XRP omits the issuer', () {
      expect(const XrplAsset.xrp().toJson(), {'currency': 'XRP'});
    });

    test('toJson of an issued asset includes currency and issuer', () {
      final asset = XrplAsset.issued(currency: 'TST', issuer: issuer);

      expect(asset.toJson(), {'currency': 'TST', 'issuer': issuer});
    });

    test('two assets with the same fields are equal', () {
      final a = XrplAsset.issued(currency: 'TST', issuer: issuer);
      final b = XrplAsset.issued(currency: 'TST', issuer: issuer);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(const XrplAsset.xrp(), equals(const XrplAsset.xrp()));
    });

    test('same currency with different issuers are not equal', () {
      final a = XrplAsset.issued(currency: 'TST', issuer: issuer);
      final b = XrplAsset.issued(
        currency: 'TST',
        issuer: 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
      );

      expect(a, isNot(equals(b)));
    });

    test('XRP and an issued asset are not equal', () {
      final issued = XrplAsset.issued(currency: 'TST', issuer: issuer);

      expect(const XrplAsset.xrp(), isNot(equals(issued)));
    });
  });
}
