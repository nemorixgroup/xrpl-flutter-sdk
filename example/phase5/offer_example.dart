// Phase 5 - 0.4.1-dev: OfferCreate & OfferCancel
//
// Demonstrates XRPL's decentralized exchange: placing an Offer to
// trade one currency for another, then cancelling it. Both use the
// same build -> autofill -> sign -> submitAndWait pipeline already
// used throughout Phase 4's Payment examples, since XrplOfferCreate
// and XrplOfferCancel implement the same XrplTransaction interface.
//
// The Offer below requests a currency ("TST") issued by the same
// account that creates the Offer. This is valid on XRPL - an issuer
// never needs a trust line for its own issued currency - and keeps
// this example self-contained, with no second account or TrustSet
// required to run it end to end.
//
// Full technical decisions:
// https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-5

import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

Future<void> createOfferExample() async {

  final connection = XrplConnection(XrplEndpoint.testnet);
  await connection.connect();

  final wallet = await fundTestWallet(connection);
  print('Funded a new wallet: ${wallet.classicAddress}');

  // TakerGets/TakerPays use XrplCurrencyAmount, since an Offer is
  // never XRP-for-XRP, at least one side is always an issued
  // currency, otherwise the trade is meaningless.
  final offer = XrplOfferCreate(
    account: wallet.classicAddress,
    takerGets: const XrplCurrencyAmount.xrp('1000000'), // 1 XRP
    takerPays: XrplCurrencyAmount.issued(
      currency: 'TST',
      issuer: wallet.classicAddress, // self-issued: no trust line needed
      value: '1',
    ),
  );

  final result = await sendTransaction(connection, offer, wallet);
  final meta = result['meta'] as Map<String, dynamic>;
  print('Result: ${meta['TransactionResult']}');
  print('Transaction hash: ${result['hash']}');

  await connection.disconnect();
}

Future<void> cancelOfferExample() async {

  final connection = XrplConnection(XrplEndpoint.testnet);
  await connection.connect();

  final wallet = await fundTestWallet(connection);

  // Create an Offer first, so there's something real to cancel.
  final offer = XrplOfferCreate(
    account: wallet.classicAddress,
    takerGets: const XrplCurrencyAmount.xrp('1000000'), // 1 XRP
    takerPays: XrplCurrencyAmount.issued(
      currency: 'TST',
      issuer: wallet.classicAddress,
      value: '1',
    ),
  );

  final filledOffer = await autofill(connection, offer);
  final signedOffer = await sign(filledOffer.toJson(), wallet);
  await submitAndWait(connection, signedOffer);

  // OfferSequence is the OfferCreate transaction's own Sequence -
  // that's how an Offer is identified on the ledger.
  final offerSequence = filledOffer.sequence!;
  print('Created Offer with sequence: $offerSequence');

  final cancel = XrplOfferCancel(
    account: wallet.classicAddress,
    offerSequence: offerSequence,
  );

  final result = await sendTransaction(connection, cancel, wallet);
  final meta = result['meta'] as Map<String, dynamic>;
  // OfferCancel always returns tesSUCCESS, even if OfferSequence
  // didn't match any Offer - confirming an Offer was actually
  // removed requires inspecting the metadata for a DeletedNode of
  // type Offer, not just this top-level result code.
  print('Result: ${meta['TransactionResult']}');

  await connection.disconnect();

}
