import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/transactions/models/xrpl_offer_cancel.dart';

void main() {
  group('XrplOfferCancel.toJson', () {
    test('includes only the required fields when nothing else is set', () {
      const cancel = XrplOfferCancel(
        account: 'rSender...',
        offerSequence: 6,
      );

      expect(cancel.toJson(), {
        'TransactionType': 'OfferCancel',
        'Account': 'rSender...',
        'OfferSequence': 6,
      });
    });

    test('includes optional fields only when they are set', () {
      const cancel = XrplOfferCancel(
        account: 'rSender...',
        offerSequence: 6,
        sequence: 7,
        fee: '12',
        lastLedgerSequence: 7108629,
      );

      expect(cancel.toJson(), {
        'TransactionType': 'OfferCancel',
        'Account': 'rSender...',
        'OfferSequence': 6,
        'Sequence': 7,
        'Fee': '12',
        'LastLedgerSequence': 7108629,
      });
    });
  });

  group('XrplOfferCancel.copyWith', () {
    test('replaces only the given fields, keeping the rest unchanged', () {
      const original = XrplOfferCancel(
        account: 'rSender...',
        offerSequence: 6,
      );

      final filled = original.copyWith(
        sequence: 7,
        fee: '12',
        lastLedgerSequence: 7108629,
      );

      expect(filled.account, original.account);
      expect(filled.offerSequence, original.offerSequence);
      expect(filled.sequence, 7);
      expect(filled.fee, '12');
      expect(filled.lastLedgerSequence, 7108629);
    });

    test('does not mutate the original instance', () {
      final original = const XrplOfferCancel(
        account: 'rSender...',
        offerSequence: 6,
      )..copyWith(sequence: 7);

      expect(original.sequence, isNull);
    });
  });
}
