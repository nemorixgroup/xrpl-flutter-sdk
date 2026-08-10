import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/address/xrpl_network.dart';
import 'package:xrpl_flutter_sdk/src/address/xrpl_x_address.dart';
import 'package:xrpl_flutter_sdk/src/codec/xrpl_base58.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return result;
}

/// Test-only helper: builds an X-address payload directly from a
/// known Account ID, mirroring XrplXAddress.deriveFrom's logic. Used
/// for official fixtures where the source material provides a
/// classic address (and therefore an Account ID) rather than a
/// public key.
String _deriveFromAccountId(
  Uint8List accountId, {
  required XrplNetwork network,
  int? tag,
}) {
  final flag = tag == null ? 0x00 : 0x01;
  final tagValue = tag ?? 0;
  final tagBytes = Uint8List(4)
    ..buffer.asByteData().setUint32(0, tagValue, Endian.little);
  final prefix = network == XrplNetwork.mainnet
      ? XrplXAddress.mainnetPrefix
      : XrplXAddress.testnetPrefix;
  final payload = Uint8List.fromList([
    ...prefix,
    ...accountId,
    flag,
    ...tagBytes,
    ...List.filled(4, 0),
  ]);
  return XrplBase58.encodeWithChecksum(payload);
}

void main() {
  group('XrplXAddress against official ripple-address-codec test vectors', () {
    // Source: the official ripple-address-codec PR that introduced
    // X-address support (github.com/ripple/ripple-address-codec/pull/14),
    // and the hwa-ripple-address-codec README, which republishes the
    // same worked examples. These vectors only publish a classic
    // address (not the underlying public key), so they're
    // reconstructed here via the known, independently-decoded
    // Account ID rather than XrplXAddress.deriveFrom's public-key
    // entry point - deriveFrom is exercised separately below, chained
    // from the classic-address vector that *does* include a public
    // key.

    test('mainnet, with the maximum 32-bit tag, matches the official vector',
        () {
      // Account ID for classic address rGWrZyQqhTp9Xu7G5Pkayo7bXjH4k4QYpf,
      // independently decoded and checksum-verified via Python.
      final accountId = _hexToBytes(
        'aa066c988c712815cc37af71472b7cbbbd4e2a0a',
      );
      final xAddress = _deriveFromAccountId(
        accountId,
        network: XrplNetwork.mainnet,
        tag: 4294967295,
      );
      expect(xAddress, 'XVLhHMPHU98es4dbozjVtdWzVrDjtV18pX8yuPT7y4xaEHi');
      expect(xAddress, startsWith('X'));
    });

    test('testnet, with a small tag, matches the official vector', () {
      // Account ID for classic address r3SVzk8ApofDJuVBPKdmbbLjWGCCXpBQ2g.
      final accountId = _hexToBytes(
        '519b7be6889cf12eaa50978ff51630e0ded92809',
      );
      final xAddress = _deriveFromAccountId(
        accountId,
        network: XrplNetwork.testnet,
        tag: 123,
      );
      expect(xAddress, 'T7oKJ3q7s94kDH6tpkBowhetT1JKfcfdSCmAXbS75iATyLD');
      expect(xAddress, startsWith('T'));
    });
  });

  group('XrplXAddress.deriveFrom chained from a verified public key', () {
    // Public key for classic address rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN,
    // the same official xrpl-dev-portal worked example already
    // verified end-to-end in xrpl_classic_address_test.dart. This
    // confirms deriveFrom's public-key entry point produces the exact
    // same result as building the payload from its Account ID
    // directly (the _deriveFromAccountId helper above) - the expected
    // value here was independently computed via the same standalone
    // Python script used throughout this SDK, not copied from an
    // official ripple-address-codec example.
    const publicKeyHex =
        'ED9434799226374926EDA3B54B1B461B4ABF7237962EAE18528FEA67595397FA32';

    test('matches the independently computed value for this public key', () {
      final xAddress = XrplXAddress.deriveFrom(
        _hexToBytes(publicKeyHex),
        network: XrplNetwork.mainnet,
        tag: 4294967295,
      );
      expect(xAddress, 'XVw9UfvRwx2mSjxk4YaDyd59dzCf6MXjiB2N8NHaGaxNR8g');
    });

    test('matches deriving the same address via its known Account ID', () {
      final viaPublicKey = XrplXAddress.deriveFrom(
        _hexToBytes(publicKeyHex),
        network: XrplNetwork.mainnet,
        tag: 4294967295,
      );
      final viaAccountId = _deriveFromAccountId(
        _hexToBytes('88a5a57c829f40f25ea83385bbde6c3d8b4ca082'),
        network: XrplNetwork.mainnet,
        tag: 4294967295,
      );
      expect(viaPublicKey, viaAccountId);
    });
  });

  group('XrplXAddress general behavior', () {
    final publicKey = _hexToBytes(
      'ED9434799226374926EDA3B54B1B461B4ABF7237962EAE18528FEA67595397FA32',
    );

    test('omitting the tag still produces a valid, deterministic address', () {
      final a =
          XrplXAddress.deriveFrom(publicKey, network: XrplNetwork.mainnet);
      final b =
          XrplXAddress.deriveFrom(publicKey, network: XrplNetwork.mainnet);
      expect(a, b);
      expect(a, startsWith('X'));
    });

    test('the same account produces different addresses per network', () {
      final mainnetAddress = XrplXAddress.deriveFrom(
        publicKey,
        network: XrplNetwork.mainnet,
      );
      final testnetAddress = XrplXAddress.deriveFrom(
        publicKey,
        network: XrplNetwork.testnet,
      );
      expect(mainnetAddress, isNot(equals(testnetAddress)));
    });

    test('a present tag changes the resulting address versus no tag', () {
      final withoutTag = XrplXAddress.deriveFrom(
        publicKey,
        network: XrplNetwork.mainnet,
      );
      final withTag = XrplXAddress.deriveFrom(
        publicKey,
        network: XrplNetwork.mainnet,
        tag: 0,
      );
      expect(withoutTag, isNot(equals(withTag)));
    });
  });

  group('XrplXAddress.deriveFrom error handling', () {
    final validPublicKey = _hexToBytes(
      'ED9434799226374926EDA3B54B1B461B4ABF7237962EAE18528FEA67595397FA32',
    );

    test('throws for a negative tag', () {
      expect(
        () => XrplXAddress.deriveFrom(
          validPublicKey,
          network: XrplNetwork.mainnet,
          tag: -1,
        ),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('throws for a tag beyond the 32-bit maximum', () {
      expect(
        () => XrplXAddress.deriveFrom(
          validPublicKey,
          network: XrplNetwork.mainnet,
          tag: XrplXAddress.maxTagValue + 1,
        ),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test('accepts the maximum valid tag without throwing', () {
      expect(
        () => XrplXAddress.deriveFrom(
          validPublicKey,
          network: XrplNetwork.mainnet,
          tag: XrplXAddress.maxTagValue,
        ),
        returnsNormally,
      );
    });

    test('propagates the public key length error from XrplClassicAddress', () {
      expect(
        () => XrplXAddress.deriveFrom(
          Uint8List(10),
          network: XrplNetwork.mainnet,
        ),
        throwsA(isA<XrplCryptoException>()),
      );
    });
  });
}
