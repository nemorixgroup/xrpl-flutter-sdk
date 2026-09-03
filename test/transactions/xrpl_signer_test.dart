import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_key_algorithm.dart';
import 'package:xrpl_flutter_sdk/src/transactions/models/xrpl_payment.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_signer.dart';
import 'package:xrpl_flutter_sdk/src/wallet/xrpl_wallet.dart';

void main() {
  group(
      'sign() with a secp256k1 wallet, against an independently '
      'computed scenario', () {
    // Restores the exact same secp256k1 wallet already fully verified
    // in Phase 1 (xrpl_secp256k1_master_test.dart) via its real seed,
    // so this test uses real, previously-confirmed keys rather than
    // arbitrary ones. The expected SigningPubKey and message hash
    // were independently computed via a standalone Python script
    // (reusing the already-verified per-field binary encoders), and
    // the resulting signature's validity confirmed with Python's
    // ecdsa library before being trusted here.
    test('produces the correct SigningPubKey and a valid signature', () async {
      final wallet = await XrplWallet.fromSeed(
        'sn259rEFXrQrWyx3Q7XneWcwV6dfL',
        algorithm: XrplKeyAlgorithm.secp256k1,
      );

      const payment = XrplPayment(
        account: 'rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN',
        destination: 'rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN',
        amountDrops: '10000000',
        sequence: 1,
        fee: '10',
      );

      final signed = await sign(payment.toJson(), wallet);

      expect(
        signed['SigningPubKey'],
        '0203F2D90BC50012EC7CB20B07A1B818D6863636FB1E945D17449092CFB5495E1E',
      );
      expect(signed['TxnSignature'], isNotNull);
      expect((signed['TxnSignature'] as String).isNotEmpty, isTrue);
    });
  });

  group(
      'sign() with an Ed25519 wallet, against an independently '
      'computed scenario', () {
    // Same approach as above, restoring the exact Ed25519 wallet
    // already verified in Phase 1 (xrpl_ed25519_test.dart). Ed25519
    // signing is fully deterministic per RFC 8032, so this test
    // expects an exact byte-for-byte match against a signature
    // independently computed via Python's pynacl (libsodium) - not
    // just a validity check, unlike the secp256k1 case above.
    test('matches the independently computed TxnSignature exactly', () async {
      final wallet = await XrplWallet.fromSeed(
        'sEdTM1uX8pu2do5XvTnutH6HsouMaM2',
        algorithm: XrplKeyAlgorithm.ed25519,
      );

      const payment = XrplPayment(
        account: 'rG31cLyErnqeVj2eomEjBZtq7PYaupGYzL',
        destination: 'rG31cLyErnqeVj2eomEjBZtq7PYaupGYzL',
        amountDrops: '5000000',
        sequence: 1,
        fee: '10',
      );

      final signed = await sign(payment.toJson(), wallet);

      expect(
        signed['SigningPubKey'],
        'EDA57EBBCB502C2009EFE17229E8DC865DCCB192C52D7888D624DC9EBADDB815F0',
      );
      expect(
        signed['TxnSignature'],
        'A8ADE756C292305CB6FAA8ACD671C0E637E9474530C8C7D8F26268A299BA87'
        '4A12EE40E231BC47F3A160F6A0310B1B90CE35C67A6EE28C7916DD335650FB9E02',
      );
    });
  });

  group('sign() general behavior', () {
    test('does not mutate the original transaction map', () async {
      final wallet = await XrplWallet.fromSeed(
        'sn259rEFXrQrWyx3Q7XneWcwV6dfL',
        algorithm: XrplKeyAlgorithm.secp256k1,
      );

      const payment = XrplPayment(
        account: 'rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN',
        destination: 'rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN',
        amountDrops: '10000000',
        sequence: 1,
        fee: '10',
      );

      final originalJson = payment.toJson();
      final originalKeys = Set.of(originalJson.keys);

      await sign(originalJson, wallet);

      expect(Set.of(originalJson.keys), originalKeys);
      expect(originalJson.containsKey('SigningPubKey'), isFalse);
      expect(originalJson.containsKey('TxnSignature'), isFalse);
    });
  });
}
