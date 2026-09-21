import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/transactions/models/xrpl_offer_create.dart';
import 'package:xrpl_flutter_sdk/src/transactions/values/xrpl_currency_amount.dart';

void main() {
  group('XrplOfferCreate.toJson', () {
    test('includes only the required fields when nothing else is set', () {
      const offer = XrplOfferCreate(
        account: 'rSender...',
        takerGets: XrplCurrencyAmount.xrp('6000000'),
        takerPays: XrplCurrencyAmount.issued(
          currency: 'GKO',
          issuer: 'ruazs5h1qEsqpke88pcqnaseXdm6od2xc',
          value: '2',
        ),
      );

      expect(offer.toJson(), {
        'TransactionType': 'OfferCreate',
        'Account': 'rSender...',
        'TakerGets': '6000000',
        'TakerPays': {
          'currency': 'GKO',
          'issuer': 'ruazs5h1qEsqpke88pcqnaseXdm6od2xc',
          'value': '2',
        },
      });
    });

    test('includes optional fields only when they are set', () {
      const offer = XrplOfferCreate(
        account: 'rSender...',
        takerGets: XrplCurrencyAmount.xrp('6000000'),
        takerPays: XrplCurrencyAmount.issued(
          currency: 'GKO',
          issuer: 'ruazs5h1qEsqpke88pcqnaseXdm6od2xc',
          value: '2',
        ),
        expiration: 595640108,
        offerSequence: 6,
        sequence: 8,
        fee: '12',
        lastLedgerSequence: 7108682,
        flags: XrplOfferCreateFlags.tfPassive,
      );

      expect(offer.toJson(), {
        'TransactionType': 'OfferCreate',
        'Account': 'rSender...',
        'TakerGets': '6000000',
        'TakerPays': {
          'currency': 'GKO',
          'issuer': 'ruazs5h1qEsqpke88pcqnaseXdm6od2xc',
          'value': '2',
        },
        'Expiration': 595640108,
        'OfferSequence': 6,
        'Sequence': 8,
        'Fee': '12',
        'LastLedgerSequence': 7108682,
        'Flags': XrplOfferCreateFlags.tfPassive,
      });
    });

    test(
        'serializes TakerGets/TakerPays as plain drops when both sides '
        'are XRP-denominated', () {
      const offer = XrplOfferCreate(
        account: 'rSender...',
        takerGets: XrplCurrencyAmount.xrp('1000000'),
        takerPays: XrplCurrencyAmount.xrp('2000000'),
      );

      expect(offer.toJson()['TakerGets'], '1000000');
      expect(offer.toJson()['TakerPays'], '2000000');
    });
  });

  group('XrplOfferCreate.copyWith', () {
    test('replaces only the given fields, keeping the rest unchanged', () {
      const original = XrplOfferCreate(
        account: 'rSender...',
        takerGets: XrplCurrencyAmount.xrp('6000000'),
        takerPays: XrplCurrencyAmount.issued(
          currency: 'GKO',
          issuer: 'ruazs5h1qEsqpke88pcqnaseXdm6od2xc',
          value: '2',
        ),
        expiration: 595640108,
      );

      final filled = original.copyWith(
        sequence: 8,
        fee: '12',
        lastLedgerSequence: 7108682,
      );

      expect(filled.account, original.account);
      expect(filled.takerGets, original.takerGets);
      expect(filled.takerPays, original.takerPays);
      expect(filled.expiration, original.expiration);
      expect(filled.sequence, 8);
      expect(filled.fee, '12');
      expect(filled.lastLedgerSequence, 7108682);
    });

    test('does not mutate the original instance', () {
      final original = const XrplOfferCreate(
        account: 'rSender...',
        takerGets: XrplCurrencyAmount.xrp('6000000'),
        takerPays: XrplCurrencyAmount.issued(
          currency: 'GKO',
          issuer: 'ruazs5h1qEsqpke88pcqnaseXdm6od2xc',
          value: '2',
        ),
      )..copyWith(sequence: 8);

      expect(original.sequence, isNull);
    });
  });

  group('XrplOfferCreateFlags', () {
    test('tfPassive matches the official value', () {
      expect(XrplOfferCreateFlags.tfPassive, 0x00010000);
    });

    test('tfImmediateOrCancel matches the official value', () {
      expect(XrplOfferCreateFlags.tfImmediateOrCancel, 0x00020000);
    });

    test('tfFillOrKill matches the official value', () {
      expect(XrplOfferCreateFlags.tfFillOrKill, 0x00040000);
    });
  });
}
