import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_key_algorithm.dart';

void main() {
  group('XrplKeyAlgorithm', () {
    test('has exactly two values: secp256k1 and ed25519', () {
      expect(XrplKeyAlgorithm.values, hasLength(2));
      expect(
        XrplKeyAlgorithm.values,
        containsAll([XrplKeyAlgorithm.secp256k1, XrplKeyAlgorithm.ed25519]),
      );
    });

    test('secp256k1 and ed25519 are distinct values', () {
      expect(
        XrplKeyAlgorithm.secp256k1,
        isNot(equals(XrplKeyAlgorithm.ed25519)),
      );
    });
  });
}
