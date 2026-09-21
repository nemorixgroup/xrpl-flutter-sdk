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

bool _containsSubsequence(Uint8List haystack, Uint8List needle) {
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var matches = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
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

  group('XrplTransactionSerializer.serialize - OfferCreate', () {
    test(
        'a full OfferCreate matches the official worked example '
        'byte-for-byte, with TakerPays as an issued currency and '
        'TakerGets as XRP', () {
      final serialized = XrplTransactionSerializer.serialize({
        'TransactionType': 'OfferCreate',
        'Flags': 524288,
        'Sequence': 1752792,
        'Expiration': 595640108,
        'OfferSequence': 1752791,
        'TakerPays': {
          'currency': 'USD',
          'issuer': 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
          'value': '7072.8',
        },
        'TakerGets': '15000000000',
        'Fee': '10',
        'SigningPubKey':
            '03EE83BB432547885C219634A1BC407A9DB0474145D69737D09CCDC'
                '63E1DEE7FE3',
        'TxnSignature':
            '30440220143759437C04F7B61F012563AFE90D8DAFC46E86035E1D9'
                '65A9CED282C97D4CE02204CFD241E86F17E011298FC1A39B63386C7'
                '4306A5DE047E213B0F29EFA4571C2C',
        'Account': 'rMBzp8CgpE441cp5PVyA9rpVV7oT8hP3ys',
      });

      expect(
        serialized,
        _hexToBytes(
          '120007220008000024001abed82a2380bf2c2019001abed764d559'
          '20ac9391400000000000000000000000000055534400000000000'
          'a20b3c85f482532a9578dbb3950b85ca06594d1654000000'
          '37e11d60068400000000000000a732103ee83bb432547885c21963'
          '4a1bc407a9db0474145d69737d09ccdc63e1dee7fe3744630440220'
          '143759437c04f7b61f012563afe90d8dafc46e86035e1d965a9ced2'
          '82c97d4ce02204cfd241e86f17e011298fc1a39b63386c74306a5de'
          '047e213b0f29efa4571c2c8114dd76483facdee26e60d8a586bb58d'
          '09f27045c46',
        ),
      );
    });

    test(
        'field order follows (typeCode, fieldCode): TakerPays (6,4) '
        'before TakerGets (6,5), and both before Fee (6,8)', () {
      final serialized = XrplTransactionSerializer.serialize({
        'TransactionType': 'OfferCreate',
        'Sequence': 1752792,
        'TakerPays': {
          'currency': 'USD',
          'issuer': 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
          'value': '7072.8',
        },
        'TakerGets': '15000000000',
        'Fee': '10',
        'Account': 'rMBzp8CgpE441cp5PVyA9rpVV7oT8hP3ys',
      });

      // TakerPays Field ID is 0x64, TakerGets is 0x65, Fee is 0x68.
      final takerPaysPosition = serialized.indexOf(0x64);
      final takerGetsPosition = serialized.indexOf(0x65);
      final feePosition = serialized.indexOf(0x68);

      expect(takerPaysPosition, lessThan(takerGetsPosition));
      expect(takerGetsPosition, lessThan(feePosition));
    });
  });

  group('XrplTransactionSerializer.serialize - OfferCancel', () {
    test('serializes OfferSequence as a standard UInt32 field', () {
      final serialized = XrplTransactionSerializer.serialize({
        'TransactionType': 'OfferCancel',
        'Account': 'rMBzp8CgpE441cp5PVyA9rpVV7oT8hP3ys',
        'OfferSequence': 1752791,
        'Sequence': 1752792,
        'Fee': '10',
      });

      // TransactionType (0x12) should be the very first field per
      // canonical order.
      expect(serialized[0], 0x12);
      // OfferSequence's 2-byte Field ID (0x20, 0x19) should appear
      // together, right before its 4-byte value (0x001abed7).
      expect(
        _containsSubsequence(serialized, _hexToBytes('2019001abed7')),
        isTrue,
      );
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
          'TransactionType': 'NotARealTransactionType',
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

  group('XrplTransactionSerializer.serialize type validation', () {
    // These exercise a hand-built map with the wrong field types - not
    // something toJson() would ever produce, but a real risk if a map
    // is constructed by hand instead. Confirms a clear
    // XrplCryptoException is thrown, not a raw TypeError.
    test(
        'throws a clear error when Sequence is a String instead of an '
        'int', () {
      expect(
        () => XrplTransactionSerializer.serialize({
          'TransactionType': 'Payment',
          'Sequence': '6', // should be an int
        }),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test(
        'throws a clear error when Account is an int instead of a '
        'String', () {
      expect(
        () => XrplTransactionSerializer.serialize({
          'TransactionType': 'Payment',
          'Account': 12345, // should be a String
        }),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test(
        'throws a clear error when LimitAmount is a String instead of '
        'a Map', () {
      expect(
        () => XrplTransactionSerializer.serialize({
          'TransactionType': 'TrustSet',
          'LimitAmount': 'not a map',
        }),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test(
        'throws a clear error when LimitAmount.currency is missing '
        'the expected type', () {
      expect(
        () => XrplTransactionSerializer.serialize({
          'TransactionType': 'TrustSet',
          'LimitAmount': {
            'currency': 123,
            'issuer': 'rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN',
            'value': '1000',
          },
        }),
        throwsA(isA<XrplCryptoException>()),
      );
    });
  });
}
