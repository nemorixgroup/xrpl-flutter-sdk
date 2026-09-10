// Phase 4 - 0.3.3-dev: submitting and confirming transactions.
//
// Two ways to do the same thing: the simple, one-call convenience
// function (sendPayment), and the detailed step-by-step pipeline
// (autofill -> sign -> submitAndWait) for callers who need to
// inspect or modify the transaction in between. Pick whichever fits
// your workflow.
//
// Full technical decisions:
// https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-4/submission

import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

Future<void> simplePaymentExample() async {
  final connection = XrplConnection(XrplEndpoint.testnet);
  await connection.connect();

  final wallet = await fundTestWallet(connection);
  print('Funded a new wallet: ${wallet.classicAddress}');

  final destinationWallet = await XrplWallet.generate(
    algorithm: XrplKeyAlgorithm.ed25519,
  );

  final result = await sendPayment(
    connection,
    senderWallet: wallet,
    destinationAddress: destinationWallet.classicAddress,
    amountDrops: '1000000',
  );

  final meta = result['meta'] as Map<String, dynamic>;
  print('Result: ${meta['TransactionResult']}');
  print('Transaction hash: ${result['hash']}');

  await connection.disconnect();
}

Future<void> detailedPaymentExample() async {
  final connection = XrplConnection(XrplEndpoint.testnet);
  await connection.connect();

  final wallet = await fundTestWallet(connection);
  final destinationWallet = await XrplWallet.generate(
    algorithm: XrplKeyAlgorithm.ed25519,
  );

  final payment = XrplPayment(
    account: wallet.classicAddress,
    destination: destinationWallet.classicAddress,
    amountDrops: '1000000',
  );

  final filled = await autofill(connection, payment);
  print('Autofilled Fee: ${filled.fee}');
  print('Autofilled Sequence: ${filled.sequence}');

  final signed = await sign(filled.toJson(), wallet);
  print('SigningPubKey: ${signed['SigningPubKey']}');

  final result = await submitAndWait(connection, signed);
  final meta = result['meta'] as Map<String, dynamic>;
  print('Result: ${meta['TransactionResult']}');

  await connection.disconnect();
}
