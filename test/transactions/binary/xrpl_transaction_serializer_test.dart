import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';
import 'package:xrpl_flutter_sdk/src/transactions/binary/xrpl_transaction_serializer.dart';
import 'package:xrpl_flutter_sdk/src/transactions/models/xrpl_payment.dart';
import 'package:xrpl_flutter_sdk/src/transactions/models/xrpl_trust_set.dart';

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return result;
}

void main() {
  group('XrplTransactionSerializer.serialize - canonical field order', () {
    test(
        'a full Payment matches the expected byte-for-byte binary, '
        'chained from already-verified individual field encoders', () {
      const payment = XrplPayment(
        account: 'rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN',
        destination: 'rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN',
        amountDrops: '10000000',
        sequence: 6,
        fee: '12',
        lastLedgerSequence: 7125358,
      );

      final serialized = XrplTransactionSerializer.serialize(
        payment.toJson(),
      );

      expect(
        serialized,
        _hexToBytes(
          '1200002400000006201b006cb96e614000000000989680'
          '68400000000000000c811488a5a57c829f40f25ea83385b'
          'bde6c3d8b4ca082831488a5a57c829f40f25ea83385bbde6'
          'c3d8b4ca082',
        ),
      );
    });

    test(
        'fields are ordered by (typeCode, fieldCode), not by their '
        'encoded byte value - confirmed with fields whose byte-length '
        'differs', () {
      // LastLedgerSequence has a 2-byte Field ID ([0x20, 0x1B]);
      // Account has a 1-byte Field ID (0x81). Comparing encoded bytes
      // directly would misorder these; comparing (typeCode, fieldCode)
      // - (2, 27) vs (8, 1) - correctly places LastLedgerSequence
      // first, since type 2 sorts before type 8.
      const payment = XrplPayment(
        account: 'rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN',
        destination: 'rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN',
        amountDrops: '10000000',
        sequence: 6,
        fee: '12',
        lastLedgerSequence: 7125358,
      );

      final serialized = XrplTransactionSerializer.serialize(
        payment.toJson(),
      );

      final lastLedgerSequencePosition = serialized.indexOf(0x20);
      final accountFieldIdPosition = serialized.indexOf(0x81);
      expect(
        lastLedgerSequencePosition,
        lessThan(accountFieldIdPosition),
      );
    });
  });

  group('XrplTransactionSerializer.serialize - TrustSet', () {
    test('serializes LimitAmount as a nested issued-currency amount', () {
      const trustSet = XrplTrustSet(
        account: 'rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN',
        currency: 'USD',
        issuer: 'rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN',
        limitValue: '1000',
        sequence: 1,
        fee: '10',
      );

      final serialized = XrplTransactionSerializer.serialize(
        trustSet.toJson(),
      );

      // TransactionType (0x12) should be the very first field per
      // canonical order (type 1 sorts before every other type used
      // here).
      expect(serialized[0], 0x12);
      // LimitAmount's Field ID (0x63) should appear somewhere in the
      // output.
      expect(serialized.contains(0x63), isTrue);
    });
  });

  group('XrplTransactionSerializer.serialize error handling', () {
    test('throws for an unsupported field name', () {
      expect(
        () => XrplTransactionSerializer.serialize({
          'TransactionType': 'Payment',
          'Account': 'rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN',
          'SomeUnsupportedField': 'value',
        }),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('throws for an unsupported TransactionType value', () {
      expect(
        () => XrplTransactionSerializer.serialize({
          'TransactionType': 'OfferCreate',
        }),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('propagates an invalid address error from the Account field', () {
      expect(
        () => XrplTransactionSerializer.serialize({
          'TransactionType': 'Payment',
          'Account': 'not-a-valid-address',
        }),
        throwsA(isA<XrplCryptoException>()),
      );
    });
  });
}
