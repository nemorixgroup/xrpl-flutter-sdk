import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/address/xrpl_classic_address.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return result;
}

void main() {
  group(
      'XrplClassicAddress against the official xrpl-dev-portal worked '
      'example', () {
    // Source: https://github.com/XRPLF/xrpl-dev-portal/blob/master/docs/concepts/accounts/addresses.md
    // This is the full worked example published directly in the
    // official XRPL documentation, independently re-verified via a
    // standalone Python script before use here.
    const publicKeyHex =
        'ED9434799226374926EDA3B54B1B461B4ABF7237962EAE18528FEA67595397FA32';
    const expectedAccountIdHex = '88a5a57c829f40f25ea83385bbde6c3d8b4ca082';
    const expectedAddress = 'rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN';

    test('accountIdFromPublicKey matches the official 20-byte Account ID', () {
      final accountId = XrplClassicAddress.accountIdFromPublicKey(
        _hexToBytes(publicKeyHex),
      );
      expect(accountId, _hexToBytes(expectedAccountIdHex));
      expect(accountId.length, 20);
    });

    test('deriveFrom matches the official classic address exactly', () {
      final address = XrplClassicAddress.deriveFrom(
        _hexToBytes(publicKeyHex),
      );
      expect(address, expectedAddress);
    });

    test('deriveFrom output starts with the expected "r" prefix', () {
      final address = XrplClassicAddress.deriveFrom(
        _hexToBytes(publicKeyHex),
      );
      expect(address, startsWith('r'));
    });
  });

  group('XrplClassicAddress general behavior', () {
    test('is deterministic for the same public key', () {
      final publicKey = Uint8List(33)..[0] = 0x02;
      final a = XrplClassicAddress.deriveFrom(publicKey);
      final b = XrplClassicAddress.deriveFrom(publicKey);
      expect(a, b);
    });

    test('produces different addresses for different public keys', () {
      final publicKeyA = Uint8List(33)..[0] = 0x02;
      final publicKeyB = Uint8List(33)
        ..[0] = 0x02
        ..[1] = 1;
      final a = XrplClassicAddress.deriveFrom(publicKeyA);
      final b = XrplClassicAddress.deriveFrom(publicKeyB);
      expect(a, isNot(equals(b)));
    });

    test('accepts a 33-byte Ed25519-style public key (0xED prefix)', () {
      final publicKey = Uint8List(33)..[0] = 0xED;
      expect(
        () => XrplClassicAddress.deriveFrom(publicKey),
        returnsNormally,
      );
    });
  });

  group('XrplClassicAddress.accountIdFromPublicKey error handling', () {
    test('throws when publicKey is shorter than 33 bytes', () {
      expect(
        () => XrplClassicAddress.accountIdFromPublicKey(Uint8List(10)),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('throws when publicKey is longer than 33 bytes', () {
      expect(
        () => XrplClassicAddress.accountIdFromPublicKey(Uint8List(40)),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('error message reports both expected and actual length', () {
      try {
        XrplClassicAddress.accountIdFromPublicKey(Uint8List(10));
        fail('Expected an XrplCryptoException');
      } on XrplCryptoException catch (e) {
        expect(e.message, contains('33'));
        expect(e.message, contains('10'));
      }
    });
  });
}
