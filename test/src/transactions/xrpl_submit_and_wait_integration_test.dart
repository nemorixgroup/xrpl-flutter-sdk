import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_endpoint.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_key_algorithm.dart';
import 'package:xrpl_flutter_sdk/src/transactions/models/xrpl_payment.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_autofill.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_signer.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_submit_and_wait.dart';
import 'package:xrpl_flutter_sdk/src/wallet/xrpl_wallet.dart';

// Integration test: this is the full, real end-to-end pipeline
// (build, autofill, sign, submit, wait for validation) against the
// public Testnet server, using the same reusable funded Ed25519
// wallet as xrpl_tx_submit_integration_test.dart's decisive test.
//
// Slower than other integration tests by design - it genuinely waits
// for a real XRPL ledger to close and validate the transaction
// (typically a few seconds), not just for a single request/response.
void main() {
  group('submitAndWait against the real public Testnet server', () {
    test(
        'a real Payment from a funded Ed25519 account is confirmed '
        'validated with tesSUCCESS', () async {
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
        amountDrops: '1000000', // 1 XRP, enough to activate the destination
      );

      final filled = await autofill(connection, payment);
      final signed = await sign(filled.toJson(), wallet);

      final result = await submitAndWait(connection, signed);

      expect(result['validated'], isTrue);
      final meta = result['meta'] as Map<String, dynamic>;
      expect(meta['TransactionResult'], 'tesSUCCESS');

      await connection.disconnect();
    });
  });
}
