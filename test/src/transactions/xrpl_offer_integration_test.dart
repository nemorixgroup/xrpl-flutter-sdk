import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

// Integration test: XrplOfferCreate and XrplOfferCancel against the
// real public Testnet server.
//
// Each test uses its own dedicated, separately funded wallet, rather
// than sharing one across tests. Reusing a single wallet for two
// back-to-back transactions from the same file caused intermittent
// LastLedgerSequence expirations in practice - likely contention on
// that account's Sequence/queue state between transactions submitted
// in quick succession. Separate wallets remove that shared state
// entirely, and this pattern will keep being useful later in Phase 5
// (Path Finding and AMM both genuinely need multiple accounts).
//
// Setup note: the offer requests a currency ("TST") issued by the
// same wallet that creates the offer. This is valid on XRPL - an
// issuer never needs a trust line for its own issued currency, since
// it can hold an effectively unlimited negative balance of it. This
// avoids funding and configuring a second wallet purely to exercise
// OfferCreate/OfferCancel, which would test trust-line setup rather
// than the Offer transactions themselves.
void main() {
  group(
      'XrplOfferCreate and XrplOfferCancel against the real public '
      'Testnet server', () {
    test(
      'creates an offer, confirms it in the ledger via metadata, then '
      'cancels it and confirms its removal',
      () async {
        final connection = XrplConnection(XrplEndpoint.testnet);
        await connection.connect();

        final wallet = await XrplWallet.fromSeed(
          'sEd7Z2q98nHustDyrsuieeEVipu4nMi',
          algorithm: XrplKeyAlgorithm.ed25519,
        );

        // Step 1: create the offer. Sell 1 XRP for 1 TST (self-issued).
        final offerCreate = XrplOfferCreate(
          account: wallet.classicAddress,
          takerGets: const XrplCurrencyAmount.xrp('1000000'), // 1 XRP
          takerPays: XrplCurrencyAmount.issued(
            currency: 'TST',
            issuer: wallet.classicAddress,
            value: '1',
          ),
        );

        final filledCreate = await autofill(connection, offerCreate);
        final signedCreate = await sign(filledCreate.toJson(), wallet);
        final createResult = await submitAndWait(connection, signedCreate);

        expect(createResult['validated'], isTrue);
        final createMeta = createResult['meta'] as Map<String, dynamic>;
        expect(createMeta['TransactionResult'], 'tesSUCCESS');

        final affectedNodes = createMeta['AffectedNodes'] as List<dynamic>;
        final createdOffer = affectedNodes.any((node) {
          final map = node as Map<String, dynamic>;
          final createdNode = map['CreatedNode'] as Map<String, dynamic>?;
          return createdNode?['LedgerEntryType'] == 'Offer';
        });
        expect(
          createdOffer,
          isTrue,
          reason: 'Expected a CreatedNode of type Offer in the metadata',
        );

        // The offer's sequence number in the ledger is the OfferCreate
        // transaction's own Sequence - this is what OfferCancel needs.
        final offerSequence = filledCreate.sequence!;

        // Step 2: cancel the offer.
        final offerCancel = XrplOfferCancel(
          account: wallet.classicAddress,
          offerSequence: offerSequence,
        );

        final filledCancel = await autofill(connection, offerCancel);
        final signedCancel = await sign(filledCancel.toJson(), wallet);
        final cancelResult = await submitAndWait(connection, signedCancel);

        expect(cancelResult['validated'], isTrue);
        final cancelMeta = cancelResult['meta'] as Map<String, dynamic>;
        // OfferCancel always returns tesSUCCESS even if there is nothing
        // to cancel - the real confirmation is the DeletedNode below.
        expect(cancelMeta['TransactionResult'], 'tesSUCCESS');

        final cancelAffectedNodes =
            cancelMeta['AffectedNodes'] as List<dynamic>;
        final deletedOffer = cancelAffectedNodes.any((node) {
          final map = node as Map<String, dynamic>;
          final deletedNode = map['DeletedNode'] as Map<String, dynamic>?;
          return deletedNode?['LedgerEntryType'] == 'Offer';
        });
        expect(
          deletedOffer,
          isTrue,
          reason: 'Expected a DeletedNode of type Offer in the metadata, '
              'confirming the offer was actually removed',
        );

        await connection.disconnect();
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'OfferCancel still returns tesSUCCESS for a non-existent '
      'OfferSequence, with no DeletedNode of type Offer',
      () async {
        final connection = XrplConnection(XrplEndpoint.testnet);
        await connection.connect();

        final wallet = await XrplWallet.fromSeed(
          'sEd7pqNMLD6zoY74h63hsziBfBCmwVp',
          algorithm: XrplKeyAlgorithm.ed25519,
        );

        // A sequence number that predates this account's very first
        // transaction (every funded account's Sequence starts at the
        // ledger index of its creation, always much larger than 1) - so
        // this is guaranteed to be in the past (a requirement for
        // OfferCancel, or rippled rejects it as temBAD_SEQUENCE) while
        // never having corresponded to a real Offer.
        final offerCancel = XrplOfferCancel(
          account: wallet.classicAddress,
          offerSequence: 1,
        );

        final filled = await autofill(connection, offerCancel);
        final signed = await sign(filled.toJson(), wallet);
        final result = await submitAndWait(connection, signed);

        expect(result['validated'], isTrue);
        final meta = result['meta'] as Map<String, dynamic>;
        expect(meta['TransactionResult'], 'tesSUCCESS');

        final affectedNodes = meta['AffectedNodes'] as List<dynamic>? ?? [];
        final deletedOffer = affectedNodes.any((node) {
          final map = node as Map<String, dynamic>;
          final deletedNode = map['DeletedNode'] as Map<String, dynamic>?;
          return deletedNode?['LedgerEntryType'] == 'Offer';
        });
        expect(deletedOffer, isFalse);

        await connection.disconnect();
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
        'throws immediately when the server rejects a malformed '
        'OfferCancel (temBAD_SEQUENCE), instead of waiting out the '
        'full expiration window', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      final wallet = await XrplWallet.fromSeed(
        'sEd7pqNMLD6zoY74h63hsziBfBCmwVp',
        algorithm: XrplKeyAlgorithm.ed25519,
      );

      // OfferSequence >= the transaction's own Sequence is invalid
      // per the official specification - rippled rejects it as
      // temBAD_SEQUENCE immediately, before it ever reaches a ledger.
      final offerCancel = XrplOfferCancel(
        account: wallet.classicAddress,
        offerSequence: 999999999,
      );

      final filled = await autofill(connection, offerCancel);
      final signed = await sign(filled.toJson(), wallet);

      final stopwatch = Stopwatch()..start();
      await expectLater(
        submitAndWait(connection, signed),
        throwsA(
          isA<XrplConnectionException>().having(
            (e) => e.message,
            'message',
            contains('temBAD_SEQUENCE'),
          ),
        ),
      );
      stopwatch.stop();

      // A world away from the ~60-100 second LastLedgerSequence
      // expiration window this would have waited out before this fix.
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 15)));

      await connection.disconnect();
    }, timeout: const Timeout(Duration(minutes: 2)),);
  });
}
