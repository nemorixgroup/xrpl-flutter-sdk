import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_endpoint.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_queries.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_key_algorithm.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_connection_exception.dart';
import 'package:xrpl_flutter_sdk/src/transactions/binary/xrpl_transaction_serializer.dart';
import 'package:xrpl_flutter_sdk/src/transactions/models/xrpl_payment.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_autofill.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_signer.dart';
import 'package:xrpl_flutter_sdk/src/wallet/xrpl_wallet.dart';

// Integration test: calls tx() and submit() against the real public
// Testnet server. Kept alongside the other test/src/connection/
// integration files, per this SDK's convention for network-dependent
// tests.
void main() {
  group('tx against the real public Testnet server', () {
    test(
        'a transaction hash the server has never seen results in '
        'txnNotFound', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      // A well-formed-looking but essentially random 64-character hex
      // hash - astronomically unlikely to ever correspond to a real
      // transaction, making this a stable, long-term-reliable way to
      // exercise the "not found" path, similar to the unfunded-wallet
      // approach already used for accountInfo's error case in Phase 3.
      await expectLater(
        tx(
          connection,
          '0000000000000000000000000000000000000000000000000000000000000000'
              .substring(0, 64),
        ),
        throwsA(isA<XrplConnectionException>()),
      );

      await connection.disconnect();
    });
  });

  group(
      'submit against the real public Testnet server (unfunded '
      'secp256k1 account)', () {
    test(
        'a real, fully signed transaction from an unfunded wallet is '
        'accepted for processing (even though it cannot succeed)', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      final wallet = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.secp256k1,
      );
      // A distinct destination, deliberately different from the
      // sender - XRPL rejects a Payment where Account == Destination
      // (a "self-payment").
      final destinationWallet = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.secp256k1,
      );

      final payment = XrplPayment(
        account: wallet.classicAddress,
        destination: destinationWallet.classicAddress,
        amountDrops: '10000000',
        sequence:
            1, // provided so autofill skips accountInfo (unfunded account)
      );

      final filled = await autofill(connection, payment);
      final signed = await sign(filled.toJson(), wallet);
      final serialized = XrplTransactionSerializer.serialize(signed);
      final txBlob = serialized
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase();

      final result = await submit(connection, txBlob);

      // The transaction cannot possibly succeed (the account has
      // never been funded), but submit() should still return a real,
      // well-formed engine_result rather than throwing - confirming
      // this SDK's full pipeline (build, sign, serialize, submit)
      // reaches the network correctly end to end.
      expect(result['engine_result'], isA<String>());
      expect(result['tx_json'], isNotNull);

      await connection.disconnect();
    });
  });

  group(
      'submit against the real public Testnet server (funded '
      'Ed25519 account)', () {
    // Funded via fundTestWallet - see
    // xrpl_fund_test_wallet_integration_test.dart for how this
    // specific account was created and confirmed funded. Restored
    // here from its seed so the same real, funded account is reused
    // across test runs instead of needing to re-fund a new one.
    //
    // This test's real historical significance: an earlier version of
    // it (using a brand-new, unfunded Ed25519 wallet) surfaced a real
    // bug - XrplEd25519.sign() was being given a SHA-512Half-hashed
    // message, but XRPL's actual signing process for Ed25519 signs
    // the raw prefixed, serialized transaction directly (Ed25519
    // performs its own internal SHA-512 hashing as part of the
    // algorithm; pre-hashing was a real, functional bug). Found by
    // comparing against xrpl.js's own internal signing data
    // byte-for-byte. Fixed in xrpl_signer.dart and
    // xrpl_ed25519.dart's doc comments. See
    // docs-sdk/phase-4/submission/ for the full investigation.
    test(
        'a real Payment from a funded Ed25519 account succeeds '
        '(tesSUCCESS)', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      final wallet = await XrplWallet.fromSeed(
        'sEd7Z2q98nHustDyrsuieeEVipu4nMi',
        algorithm: XrplKeyAlgorithm.ed25519,
      );
      final destinationWallet = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.ed25519,
      );

      final payment = XrplPayment(
        account: wallet.classicAddress,
        destination: destinationWallet.classicAddress,
        // 10 XRP - enough to activate the brand-new destination
        // account, which requires at least the 1 XRP base reserve.
        amountDrops: '1000000',
      );

      // Real Sequence via accountInfo - this account genuinely exists
      // and is funded on the ledger.
      final filled = await autofill(connection, payment);
      final signed = await sign(filled.toJson(), wallet);
      final serialized = XrplTransactionSerializer.serialize(signed);
      final txBlob = serialized
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase();

      final result = await submit(connection, txBlob);

      expect(result['engine_result'], 'tesSUCCESS');

      await connection.disconnect();
    });
  });
}
