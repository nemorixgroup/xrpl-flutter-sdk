import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_ed25519.dart';

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return result;
}

void main() {
  group('XrplEd25519.sign against an independently computed vector', () {
    // Reuses the same Ed25519 private key already verified in
    // xrpl_ed25519_test.dart (Phase 1). Unlike secp256k1, Ed25519
    // signing is standardized and fully deterministic (RFC 8032), so
    // unlike the secp256k1 signing test, which could only verify
    // structural validity - this signature is expected to match an
    // independently computed one byte-for-byte, computed here via
    // Python's pynacl (libsodium).
    final privateKey = _hexToBytes(
      '0bf5f1f124c884b1a5ae4a48c816fcf554fc3a0d9a07c0f7eb1ca91f7b94814c',
    );
    final messageHash = _hexToBytes(
      '6dd9b74a2a531cdb5df8ad1eb1c2bc4ede95a1e6613f28d646966ce5daa3f565',
    );

    test('matches the independently computed signature exactly', () async {
      final signature = await XrplEd25519.sign(messageHash, privateKey);
      expect(
        signature,
        _hexToBytes(
          '114d94d79b0bdce0d05ccb0fbadf0b6b4afc81a11ff42a28dbd12266897'
          'a26b55cef84cd2377b54a49b496ac4d8a672844566f681a5e6cb8e36869'
          'edd066510b',
        ),
      );
    });

    test('produces exactly 64 bytes', () async {
      final signature = await XrplEd25519.sign(messageHash, privateKey);
      expect(signature.length, 64);
    });

    test(
        'is deterministic: signing the same hash twice yields the same '
        'signature', () async {
      final first = await XrplEd25519.sign(messageHash, privateKey);
      final second = await XrplEd25519.sign(messageHash, privateKey);
      expect(first, second);
    });
  });
}
