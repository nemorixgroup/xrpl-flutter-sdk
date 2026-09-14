import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_endpoint.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_key_algorithm.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_connection_exception.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';
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

  group('sendTransaction propagation of a deeper error (sign())', () {
    // This chains all the way through autofill's skip-lookup path
    // (no network calls at all, since sequence/fee/lastLedgerSequence
    // are already provided) directly into sign()'s Account-mismatch
    // check - confirming sendTransaction propagates a genuinely
    // different exception type (XrplCryptoException, not
    // XrplConnectionException) from a layer deeper than the
    // "not connected" check above, rather than only ever surfacing
    // the first, shallowest kind of failure.
    test(
        "propagates sign()'s Account-mismatch XrplCryptoException, "
        'not just connection-level errors', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      final signingWallet = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.ed25519,
      );
      final differentWallet = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.secp256k1,
      );

      // Built for differentWallet's account, but sent with
      // signingWallet below - and every field autofill would
      // otherwise need to look up is already provided, so this never
      // touches the network at all before sign() rejects the
      // mismatch.
      final payment = XrplPayment(
        account: differentWallet.classicAddress,
        destination: 'rSomeOtherAddress...',
        amountDrops: '10000000',
        sequence: 1,
        fee: '10',
        lastLedgerSequence: 1000000,
      );

      await expectLater(
        sendTransaction(connection, payment, signingWallet),
        throwsA(isA<XrplCryptoException>()),
      );
    });
  });
}
