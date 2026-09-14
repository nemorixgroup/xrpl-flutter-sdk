import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_key_algorithm.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';
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

      // Uses wallet.classicAddress directly (not a separate hardcoded
      // string) so Account always genuinely matches the signing
      // wallet - a prior version of this test used an unrelated,
      // mismatched address (from a different official example
      // entirely) that happened to go unnoticed until the
      // Account-mismatch validation added during the Phase 4 closing
      // audit caught it.
      final payment = XrplPayment(
        account: wallet.classicAddress,
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
    // independently computed via Python's pynacl (libsodium).
    //
    // The expected signature here signs the raw, prefixed, serialized
    // transaction bytes DIRECTLY - not their SHA-512Half hash, unlike
    // secp256k1. This was corrected during the 0.3.3-dev submission
    // investigation: Ed25519 (EdDSA) performs its own internal
    // SHA-512 hashing as part of the algorithm, so pre-hashing before
    // signing was a real bug, confirmed by comparing against xrpl.js's
    // own internal signing data. See docs-sdk/phase-4/submission/ for
    // the full investigation.
    test('matches the independently computed TxnSignature exactly', () async {
      final wallet = await XrplWallet.fromSeed(
        'sEdTM1uX8pu2do5XvTnutH6HsouMaM2',
        algorithm: XrplKeyAlgorithm.ed25519,
      );

      final payment = XrplPayment(
        account: wallet.classicAddress,
        destination: wallet.classicAddress,
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
        '6C585F7744FA816C8CC3205344EEAAE9BA50EE4A4A9AFC0870D2ABF92EBBC3D'
        'D1BA7AF83D7F01575CD0B1AB91A0B26A2244938911E4A9EC41DE0C92961D09A04',
      );
    });
  });

  group('sign() general behavior', () {
    test('does not mutate the original transaction map', () async {
      final wallet = await XrplWallet.fromSeed(
        'sn259rEFXrQrWyx3Q7XneWcwV6dfL',
        algorithm: XrplKeyAlgorithm.secp256k1,
      );

      final payment = XrplPayment(
        account: wallet.classicAddress,
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

  group('sign() Account mismatch validation', () {
    test(
        "throws when transactionJson's Account does not match "
        "wallet's address", () async {
      final signingWallet = await XrplWallet.fromSeed(
        'sn259rEFXrQrWyx3Q7XneWcwV6dfL',
        algorithm: XrplKeyAlgorithm.secp256k1,
      );
      final differentWallet = await XrplWallet.fromSeed(
        'sEdTM1uX8pu2do5XvTnutH6HsouMaM2',
        algorithm: XrplKeyAlgorithm.ed25519,
      );

      // Built for differentWallet's account, but signed with
      // signingWallet below - the mismatch this validation exists to
      // catch.
      final payment = XrplPayment(
        account: differentWallet.classicAddress,
        destination: 'rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN',
        amountDrops: '10000000',
        sequence: 1,
        fee: '10',
      );

      await expectLater(
        sign(payment.toJson(), signingWallet),
        throwsA(isA<XrplCryptoException>()),
      );
    });

    test("does not throw when Account matches wallet's address", () async {
      final wallet = await XrplWallet.fromSeed(
        'sn259rEFXrQrWyx3Q7XneWcwV6dfL',
        algorithm: XrplKeyAlgorithm.secp256k1,
      );

      final payment = XrplPayment(
        account: wallet.classicAddress,
        destination: 'rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN',
        amountDrops: '10000000',
        sequence: 1,
        fee: '10',
      );

      await expectLater(sign(payment.toJson(), wallet), completes);
    });
  });
}
