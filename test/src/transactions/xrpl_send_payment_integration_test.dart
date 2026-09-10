import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_endpoint.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_key_algorithm.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_send_payment.dart';
import 'package:xrpl_flutter_sdk/src/wallet/xrpl_wallet.dart';

// Integration test: the full convenience pipeline (sendPayment, built
// on sendTransaction) against the real public Testnet server, reusing
// the same funded Ed25519 wallet as the other submission integration
// tests.
void main() {
  group('sendPayment against the real public Testnet server', () {
    test('sends a real payment in one call and confirms tesSUCCESS', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      final wallet = await XrplWallet.fromSeed(
        'sEd7Z2q98nHustDyrsuieeEVipu4nMi',
        algorithm: XrplKeyAlgorithm.ed25519,
      );
      final destinationWallet = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.ed25519,
      );

      final result = await sendPayment(
        connection,
        senderWallet: wallet,
        destinationAddress: destinationWallet.classicAddress,
        amountDrops: '1000000', // 1 XRP
      );

      expect(result['validated'], isTrue);
      final meta = result['meta'] as Map<String, dynamic>;
      expect(meta['TransactionResult'], 'tesSUCCESS');

      await connection.disconnect();
    });
  });
}
