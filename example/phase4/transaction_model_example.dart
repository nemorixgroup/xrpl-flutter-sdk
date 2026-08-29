// Phase 4 - 0.3.1-dev: transaction model and autofill.
//
// Full technical decisions:
// https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-4/transaction-model

import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

/// XrplPayment and XrplTrustSet describe a transaction's content;
/// autofill fills in the "bookkeeping" fields (Sequence, Fee,
/// LastLedgerSequence) automatically, the same way xrpl.js does.
/// Neither of these transactions is signed or submitted yet - that's
/// 0.3.2-dev and 0.3.3-dev.
Future<void> transactionModelExample() async {
  final connection = XrplConnection(XrplEndpoint.testnet);
  await connection.connect();

  // NOTE: this address (rG1QQv2nh2gr7RCZ1P8YYcBUKCCN633jCn) is
  // a placeholder (taken from xrpl.js's  documentation),
  //  not a real account this SDK owns or controls.
  // `sequence` is provided explicitly below specifically so autofill
  // never needs to look this address up on the network - if you want
  // to see autofill's full flow (including a real Sequence looked up
  // via accountInfo), replace this with your own funded Testnet
  // address and remove the `sequence:` argument. Testnet resets
  // periodically, so any hardcoded "known" address, including this
  // one - may not exist or stay funded over time.
  const payment = XrplPayment(
    account: 'rG1QQv2nh2gr7RCZ1P8YYcBUKCCN633jCn',
    destination: 'rG1QQv2nh2gr7RCZ1P8YYcBUKCCN633jCn',
    amountDrops: '10000000', // 10 XRP
    sequence: 1,
  );
  print('Payment before autofill: ${payment.toJson()}');

  final filledPayment = await autofill(connection, payment);
  print('Payment after autofill: ${filledPayment.toJson()}');

  const trustSet = XrplTrustSet(
    account: 'rG1QQv2nh2gr7RCZ1P8YYcBUKCCN633jCn',
    currency: 'USD',
    issuer: 'rIssuerAddress...',
    limitValue: '1000',
    sequence: 1,
  );
  final filledTrustSet = await autofill(
    connection,
    trustSet,
    feeStrategy: XrplFeeStrategy.minimum,
  );
  print('TrustSet after autofill (minimum fee): ${filledTrustSet.toJson()}');

  await connection.disconnect();
}
