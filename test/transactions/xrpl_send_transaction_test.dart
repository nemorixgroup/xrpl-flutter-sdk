import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_endpoint.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_key_algorithm.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_connection_exception.dart';
import 'package:xrpl_flutter_sdk/src/transactions/models/xrpl_payment.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_send_transaction.dart';
import 'package:xrpl_flutter_sdk/src/wallet/xrpl_wallet.dart';

void main() {
  group('sendTransaction without a prior connect', () {
    test(
        'propagates the "not connected" error from autofill, without '
        'attempting to sign or submit', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      final wallet = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.ed25519,
      );

      const payment = XrplPayment(
        account: 'rSomeAddress...',
        destination: 'rSomeOtherAddress...',
        amountDrops: '10000000',
      );

      await expectLater(
        sendTransaction(connection, payment, wallet),
        throwsA(isA<XrplConnectionException>()),
      );
    });
  });
}
