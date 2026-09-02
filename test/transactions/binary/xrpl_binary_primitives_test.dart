import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';
import 'package:xrpl_flutter_sdk/src/transactions/binary/xrpl_binary_primitives.dart';

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return result;
}

void main() {
  group('XrplBinaryPrimitives.encodeLengthPrefix', () {
    test('encodes 20 (an AccountID length) as a single byte', () {
      expect(XrplBinaryPrimitives.encodeLengthPrefix(20), [0x14]);
    });

    test('encodes 33 (a compressed public key length) as a single byte', () {
      expect(XrplBinaryPrimitives.encodeLengthPrefix(33), [0x21]);
    });

    test('encodes the boundary value 192 correctly', () {
      expect(XrplBinaryPrimitives.encodeLengthPrefix(192), [192]);
    });

    test('throws for a length beyond the 1-byte form (193)', () {
      expect(
        () => XrplBinaryPrimitives.encodeLengthPrefix(193),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('throws for a negative length', () {
      expect(
        () => XrplBinaryPrimitives.encodeLengthPrefix(-1),
        throwsA(isA<XrplCryptoException>()),
      );
    });
  });

  group(
      'XrplBinaryPrimitives.encodeUInt16 against the official '
      'OfferCreate example', () {
    test('matches TransactionType (OfferCreate = 7)', () {
      expect(XrplBinaryPrimitives.encodeUInt16(7), _hexToBytes('0007'));
    });
  });

  group(
      'XrplBinaryPrimitives.encodeUInt32 against the official '
      'OfferCreate example', () {
    test('matches Flags (524288)', () {
      expect(
        XrplBinaryPrimitives.encodeUInt32(524288),
        _hexToBytes('00080000'),
      );
    });

    test('matches Sequence (1752792)', () {
      expect(
        XrplBinaryPrimitives.encodeUInt32(1752792),
        _hexToBytes('001abed8'),
      );
    });
  });

  group(
      'XrplBinaryPrimitives.encodeAccountId against an already-verified '
      'classic address', () {
    // Reuses the same official worked example already verified in
    // xrpl_classic_address_test.dart: address <-> Account ID.
    test('matches the official rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN vector', () {
      final encoded = XrplBinaryPrimitives.encodeAccountId(
        'rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN',
      );
      expect(
        encoded,
        _hexToBytes('1488a5a57c829f40f25ea83385bbde6c3d8b4ca082'),
      );
    });

    test('throws for an address with an invalid checksum', () {
      expect(
        () => XrplBinaryPrimitives.encodeAccountId('rInvalidAddress123'),
        throwsA(isA<XrplCryptoException>()),
      );
    });
  });

  group(
      'XrplBinaryPrimitives.encodeBlob against the official OfferCreate '
      'example', () {
    test('matches the official SigningPubKey (33 bytes)', () {
      const pubKeyHex =
          '03ee83bb432547885c219634a1bc407a9db0474145d69737d09ccdc63e1dee7fe3';
      final encoded = XrplBinaryPrimitives.encodeBlob(pubKeyHex);
      expect(encoded, _hexToBytes('21$pubKeyHex'));
    });
  });
}
