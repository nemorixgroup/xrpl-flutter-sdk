// Phase 4 - 0.3.2-dev: transaction signing.
//
// Full technical decisions:
// https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-4/signing

import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

/// sign() ties together autofill (0.3.1-dev) and the new binary
/// codec/signing pieces (0.3.2-dev): the result is a fully signed
/// transaction, ready for submission in 0.3.3-dev.
Future<void> signingExample() async {
  final connection = XrplConnection(XrplEndpoint.testnet);
  await connection.connect();

  final wallet = await XrplWallet.generate(
    algorithm: XrplKeyAlgorithm.ed25519,
  );

  const payment = XrplPayment(
    account: 'rG1QQv2nh2gr7RCZ1P8YYcBUKCCN633jCn',
    destination: 'rG1QQv2nh2gr7RCZ1P8YYcBUKCCN633jCn',
    amountDrops: '10000000',
    sequence: 1, // provided so this example doesn't need a funded account
  );

  final filled = await autofill(connection, payment);
  final signed = await sign(filled.toJson(), wallet);

  print('SigningPubKey: ${signed['SigningPubKey']}');
  print('TxnSignature: ${signed['TxnSignature']}');

  await connection.disconnect();
}
