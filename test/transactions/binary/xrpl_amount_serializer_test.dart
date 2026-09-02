import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';
import 'package:xrpl_flutter_sdk/src/transactions/binary/xrpl_amount_serializer.dart';

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return result;
}

void main() {
  group(
      'XrplAmountSerializer.encodeXrpAmount against the official '
      'OfferCreate example', () {
    test('matches TakerGets (15000000000 drops)', () {
      final encoded = XrplAmountSerializer.encodeXrpAmount('15000000000');
      expect(encoded, _hexToBytes('400000037e11d600'));
    });

    test('matches Fee (10 drops)', () {
      final encoded = XrplAmountSerializer.encodeXrpAmount('10');
      expect(encoded, _hexToBytes('400000000000000a'));
    });

    test('throws for a negative amount', () {
      expect(
        () => XrplAmountSerializer.encodeXrpAmount('-1'),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('throws for a non-numeric value', () {
      expect(
        () => XrplAmountSerializer.encodeXrpAmount('abc'),
        throwsA(isA<XrplCryptoException>()),
      );
    });
  });

  group(
      'XrplAmountSerializer.encodeIssuedCurrencyAmount against the '
      'official OfferCreate example (TakerPays: 7072.8 USD)', () {
    // The issuer address here is independently derived (via this SDK's
    // own already-verified base58 checksum encoding) from the exact
    // 20-byte issuer Account ID published in the official example's
    // binary - not an official address string itself, but a
    // deterministic, verifiable encoding of official bytes.
    test('matches the official 48-byte value+currency+issuer encoding', () {
      final encoded = XrplAmountSerializer.encodeIssuedCurrencyAmount(
        currency: 'USD',
        issuer: 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
        value: '7072.8',
      );
      expect(
        encoded,
        _hexToBytes(
          'd55920ac9391400000000000000000000000000055534400000000'
          '000a20b3c85f482532a9578dbb3950b85ca06594d1',
        ),
      );
    });
  });

  group('XrplAmountSerializer.encodeIssuedCurrencyAmount general behavior', () {
    test('encodes a whole-number value correctly (1000)', () {
      final encoded = XrplAmountSerializer.encodeIssuedCurrencyAmount(
        currency: 'USD',
        issuer: 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
        value: '1000',
      );
      final valueBytes = encoded.sublist(0, 8);
      expect(valueBytes, _hexToBytes('d5438d7ea4c68000'));
    });

    test('encodes zero with the special fixed encoding', () {
      final encoded = XrplAmountSerializer.encodeIssuedCurrencyAmount(
        currency: 'USD',
        issuer: 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
        value: '0',
      );
      final valueBytes = encoded.sublist(0, 8);
      expect(valueBytes, _hexToBytes('8000000000000000'));
    });

    test(
        'rejects a currency code that is neither 3 letters nor 40 hex '
        'characters', () {
      expect(
        () => XrplAmountSerializer.encodeIssuedCurrencyAmount(
          currency: 'TOOLONG',
          issuer: 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
          value: '100',
        ),
        throwsA(isA<XrplCryptoException>()),
      );
    });
  });
}
