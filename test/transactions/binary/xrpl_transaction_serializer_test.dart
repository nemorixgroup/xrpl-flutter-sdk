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

  group('XrplTransactionSerializer.serialize - AMMCreate', () {
    // Every expected hex below was produced by the official xrpl-py
    // library's binary codec, not by this SDK, so these tests compare
    // against an independent implementation.
    test(
        'XRP Amount and an issued Amount2 match the xrpl-py binary '
        'byte-for-byte', () {
      final serialized = XrplTransactionSerializer.serialize({
        'TransactionType': 'AMMCreate',
        'Account': 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe',
        'Amount': '10000000',
        'Amount2': {
          'currency': 'TST',
          'issuer': 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd',
          'value': '25',
        },
        'TradingFee': 500,
        'Fee': '200000',
        'Sequence': 7,
        'LastLedgerSequence': 100,
        'SigningPubKey': 'ED5F5AC8B98974A3CA843326D9B88CEBD0560177'
            'B973EE0B149F782911E5E8A9C1',
      });

      expect(
        serialized,
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

    test(
        'an issued Amount (not only XRP) and the maximum TradingFee '
        '1000 match the xrpl-py binary byte-for-byte', () {
      final serialized = XrplTransactionSerializer.serialize({
        'TransactionType': 'AMMCreate',
        'Account': 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe',
        'Amount': {
          'currency': 'USD',
          'issuer': 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
          'value': '1.5',
        },
        'Amount2': {
          'currency': 'TST',
          'issuer': 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd',
          'value': '25',
        },
        'TradingFee': 1000,
        'Fee': '200000',
        'Sequence': 8,
        'LastLedgerSequence': 101,
        'SigningPubKey': 'ED5F5AC8B98974A3CA843326D9B88CEBD0560177'
            'B973EE0B149F782911E5E8A9C1',
      });

      expect(
        serialized,
        _hexToBytes(
          '1200231503e82400000008201b0000006561d485543df729c00000'
          '000000000000000000000055534400000000000a20b3c85f482532'
          'a9578dbb3950b85ca06594d1684000000000030d406bd4c8e1bc9b'
          'f040000000000000000000000000005453540000000000f2f97c43'
          '01c80d60f86653a319aa7f302c70b83b7321ed5f5ac8b98974a3ca'
          '843326d9b88cebd0560177b973ee0b149f782911e5e8a9c18114f6'
          '67b0ca50cc7709a220b0561b85e53a48461fa8',
        ),
      );
    });

    test(
        'a TradingFee of 0 is serialized, not omitted, and matches '
        'the xrpl-py binary byte-for-byte', () {
      final serialized = XrplTransactionSerializer.serialize({
        'TransactionType': 'AMMCreate',
        'Account': 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe',
        'Amount': '5000000',
        'Amount2': {
          'currency': 'TST',
          'issuer': 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd',
          'value': '10',
        },
        'TradingFee': 0,
        'Fee': '200000',
        'Sequence': 9,
        'SigningPubKey': 'ED5F5AC8B98974A3CA843326D9B88CEBD0560177'
            'B973EE0B149F782911E5E8A9C1',
      });

      expect(
        serialized,
        _hexToBytes(
          '12002315000024000000096140000000004c4b4068400000000003'
          '0d406bd4c38d7ea4c6800000000000000000000000000054535400'
          '00000000f2f97c4301c80d60f86653a319aa7f302c70b83b7321ed'
          '5f5ac8b98974a3ca843326d9b88cebd0560177b973ee0b149f7829'
          '11e5e8a9c18114f667b0ca50cc7709a220b0561b85e53a48461fa8',
        ),
      );
    });

    test('throws a clear error when TradingFee is a String instead of an int',
        () {
      expect(
        () => XrplTransactionSerializer.serialize({
          'TransactionType': 'AMMCreate',
          'TradingFee': '500', // should be an int
        }),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('throws a clear error when Amount2 is neither a String nor a Map', () {
      expect(
        () => XrplTransactionSerializer.serialize({
          'TransactionType': 'AMMCreate',
          'Amount2': 12345, // should be a String or a Map
        }),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('throws a clear error when Amount is neither a String nor a Map', () {
      expect(
        () => XrplTransactionSerializer.serialize({
          'TransactionType': 'AMMCreate',
          'Amount': 12345, // should be a String or a Map
        }),
        throwsA(isA<XrplCryptoException>()),
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

  group('XrplTransactionSerializer.serialize - AccountSet (minimal)', () {
    test('SetFlag 8 matches the xrpl-py binary byte-for-byte', () {
      final serialized = XrplTransactionSerializer.serialize({
        'TransactionType': 'AccountSet',
        'Account': 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe',
        'SetFlag': 8,
        'Fee': '12',
        'Sequence': 9,
        'LastLedgerSequence': 102,
        'SigningPubKey': 'ED5F5AC8B98974A3CA843326D9B88CEBD0560177'
            'B973EE0B149F782911E5E8A9C1',
      });

      expect(
        serialized,
        _hexToBytes(
          '1200032400000009201b0000006620210000000868400000000000000c73'
          '21ed5f5ac8b98974a3ca843326d9b88cebd0560177b973ee0b149f782911'
          'e5e8a9c18114f667b0ca50cc7709a220b0561b85e53a48461fa8',
        ),
      );
    });
  });

  group('XrplTransactionSerializer.serialize - AMMDeposit', () {
    // Every expected hex below was produced by the official xrpl-py
    // library's binary codec, not by this SDK, so these tests compare
    // against an independent implementation. The pool is XRP / TST.
    const issuer = 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd';

    // The LP token a deposit buys: a 40-character hex currency code
    // issued by the AMM account, as observed on the real Testnet.
    const lpTokenOut = {
      'currency': '039C99CD9AB0B70B32ECDA51EAAE471625608EA2',
      'issuer': 'rNJSNwbggDhEBwhRXNeyeY7G2Xy3gxLjYH',
      'value': '100',
    };

    const tstAmount = {
      'currency': 'TST',
      'issuer': issuer,
      'value': '10',
    };

    Map<String, dynamic> deposit(Map<String, dynamic> fields) {
      return {
        'TransactionType': 'AMMDeposit',
        'Account': 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe',
        'Asset': {'currency': 'XRP'},
        'Asset2': {'currency': 'TST', 'issuer': issuer},
        'Fee': '10',
        'Sequence': 9,
        'LastLedgerSequence': 102,
        'SigningPubKey': 'ED5F5AC8B98974A3CA843326D9B88CEBD0560177'
            'B973EE0B149F782911E5E8A9C1',
        ...fields,
      };
    }

    test('tfLPToken with LPTokenOut matches xrpl-py byte-for-byte', () {
      final serialized = XrplTransactionSerializer.serialize(
        deposit({'Flags': 0x00010000, 'LPTokenOut': lpTokenOut}),
      );

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

    test('tfTwoAsset with Amount and Amount2 matches xrpl-py byte-for-byte',
        () {
      final serialized = XrplTransactionSerializer.serialize(
        deposit({
          'Flags': 0x00100000,
          'Amount': '1000000',
          'Amount2': tstAmount,
        }),
      );

      expect(
        serialized,
        _hexToBytes(
          '12002422001000002400000009201b000000666140000000000f42'
          '4068400000000000000a6bd4c38d7ea4c680000000000000000000'
          '000000005453540000000000f2f97c4301c80d60f86653a319aa7f'
          '302c70b83b7321ed5f5ac8b98974a3ca843326d9b88cebd0560177'
          'b973ee0b149f782911e5e8a9c18114f667b0ca50cc7709a220b056'
          '1b85e53a48461fa803180000000000000000000000000000000000'
          '00000004180000000000000000000000005453540000000000f2f9'
          '7c4301c80d60f86653a319aa7f302c70b83b',
        ),
      );
    });

    test('tfSingleAsset with only Amount matches xrpl-py byte-for-byte', () {
      final serialized = XrplTransactionSerializer.serialize(
        deposit({'Flags': 0x00080000, 'Amount': '1000000'}),
      );

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

    test(
        'tfOneAssetLPToken with Amount and LPTokenOut matches xrpl-py '
        'byte-for-byte', () {
      final serialized = XrplTransactionSerializer.serialize(
        deposit({
          'Flags': 0x00200000,
          'Amount': '1000000',
          'LPTokenOut': lpTokenOut,
        }),
      );

      expect(
        serialized,
        _hexToBytes(
          '12002422002000002400000009201b000000666140000000000f42'
          '4068400000000000000a6019d5038d7ea4c68000039c99cd9ab0b7'
          '0b32ecda51eaae471625608ea291e5c3d526d6af03e629efbc0a09'
          '5613116ea1007321ed5f5ac8b98974a3ca843326d9b88cebd05601'
          '77b973ee0b149f782911e5e8a9c18114f667b0ca50cc7709a220b0'
          '561b85e53a48461fa8031800000000000000000000000000000000'
          '0000000004180000000000000000000000005453540000000000f2'
          'f97c4301c80d60f86653a319aa7f302c70b83b',
        ),
      );
    });

    test('tfLimitLPToken with Amount and EPrice matches xrpl-py byte-for-byte',
        () {
      final serialized = XrplTransactionSerializer.serialize(
        deposit({
          'Flags': 0x00400000,
          'Amount': '1000000',
          'EPrice': '100000',
        }),
      );

      expect(
        serialized,
        _hexToBytes(
          '12002422004000002400000009201b000000666140000000000f42'
          '4068400000000000000a601b40000000000186a07321ed5f5ac8b9'
          '8974a3ca843326d9b88cebd0560177b973ee0b149f782911e5e8a9'
          'c18114f667b0ca50cc7709a220b0561b85e53a48461fa803180000'
          '000000000000000000000000000000000000041800000000000000'
          '00000000005453540000000000f2f97c4301c80d60f86653a319aa'
          '7f302c70b83b',
        ),
      );
    });

    test(
        'tfTwoAssetIfEmpty with Amount and Amount2 matches xrpl-py '
        'byte-for-byte', () {
      final serialized = XrplTransactionSerializer.serialize(
        deposit({
          'Flags': 0x00800000,
          'Amount': '1000000',
          'Amount2': tstAmount,
        }),
      );

      expect(
        serialized,
        _hexToBytes(
          '12002422008000002400000009201b000000666140000000000f42'
          '4068400000000000000a6bd4c38d7ea4c680000000000000000000'
          '000000005453540000000000f2f97c4301c80d60f86653a319aa7f'
          '302c70b83b7321ed5f5ac8b98974a3ca843326d9b88cebd0560177'
          'b973ee0b149f782911e5e8a9c18114f667b0ca50cc7709a220b056'
          '1b85e53a48461fa803180000000000000000000000000000000000'
          '00000004180000000000000000000000005453540000000000f2f9'
          '7c4301c80d60f86653a319aa7f302c70b83b',
        ),
      );
    });

    test(
        'a pool of two issued assets (neither is XRP) matches xrpl-py '
        'byte-for-byte', () {
      final serialized = XrplTransactionSerializer.serialize(
        deposit({
          'Flags': 0x00080000,
          'Asset': {
            'currency': 'USD',
            'issuer': 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
          },
          'Amount': tstAmount,
        }),
      );

      expect(
        serialized,
        _hexToBytes(
          '12002422000800002400000009201b0000006661d4c38d7ea4c680'
          '000000000000000000000000005453540000000000f2f97c4301c8'
          '0d60f86653a319aa7f302c70b83b68400000000000000a7321ed5f'
          '5ac8b98974a3ca843326d9b88cebd0560177b973ee0b149f782911'
          'e5e8a9c18114f667b0ca50cc7709a220b0561b85e53a48461fa803'
          '1800000000000000000000000055534400000000000a20b3c85f48'
          '2532a9578dbb3950b85ca06594d104180000000000000000000000'
          '005453540000000000f2f97c4301c80d60f86653a319aa7f302c70'
          'b83b',
        ),
      );
    });

    test('Asset and Asset2 are serialized after Account (type 24 sorts last)',
        () {
      final serialized = XrplTransactionSerializer.serialize(
        deposit({'Flags': 0x00080000, 'Amount': '1000000'}),
      );

      // Account's Field ID is 0x81; Asset's is [0x03, 0x18].
      final accountPosition = serialized.indexOf(0x81);
      final assetPosition = serialized.indexOf(0x18);
      expect(accountPosition, lessThan(assetPosition));
    });

    test('throws when Asset is not a Map', () {
      expect(
        () => XrplTransactionSerializer.serialize({
          'TransactionType': 'AMMDeposit',
          'Asset': 'XRP', // should be a Map
        }),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('throws when an XRP Asset is given an issuer', () {
      expect(
        () => XrplTransactionSerializer.serialize({
          'TransactionType': 'AMMDeposit',
          'Asset': {'currency': 'XRP', 'issuer': issuer},
        }),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('throws when a token Asset has no issuer', () {
      expect(
        () => XrplTransactionSerializer.serialize({
          'TransactionType': 'AMMDeposit',
          'Asset2': {'currency': 'TST'},
        }),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('throws when an Asset issuer is not a String', () {
      expect(
        () => XrplTransactionSerializer.serialize({
          'TransactionType': 'AMMDeposit',
          'Asset2': {'currency': 'TST', 'issuer': 12345},
        }),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('throws when LPTokenOut is a String (LP tokens are never XRP)', () {
      expect(
        () => XrplTransactionSerializer.serialize({
          'TransactionType': 'AMMDeposit',
          'LPTokenOut': '100', // should be a Map
        }),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('throws when a 40-character currency code is not valid hex', () {
      expect(
        () => XrplTransactionSerializer.serialize({
          'TransactionType': 'AMMDeposit',
          'LPTokenOut': {
            'currency': 'Z' * 40, // not hexadecimal
            'issuer': 'rNJSNwbggDhEBwhRXNeyeY7G2Xy3gxLjYH',
            'value': '100',
          },
        }),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('throws when EPrice is neither a String nor a Map', () {
      expect(
        () => XrplTransactionSerializer.serialize({
          'TransactionType': 'AMMDeposit',
          'EPrice': 12345, // should be a String or a Map
        }),
        throwsA(isA<XrplCryptoException>()),
      );
    });
  });
}
