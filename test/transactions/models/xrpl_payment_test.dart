import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/transactions/models/xrpl_payment.dart';

void main() {
  group('XrplPayment.toJson', () {
    test('includes only the required fields when nothing else is set', () {
      const payment = XrplPayment(
        account: 'rSender...',
        destination: 'rReceiver...',
        amountDrops: '10000000',
      );

      expect(payment.toJson(), {
        'TransactionType': 'Payment',
        'Account': 'rSender...',
        'Destination': 'rReceiver...',
        'Amount': '10000000',
      });
    });

    test('includes optional fields only when they are set', () {
      const payment = XrplPayment(
        account: 'rSender...',
        destination: 'rReceiver...',
        amountDrops: '10000000',
        destinationTag: 12345,
        sequence: 6,
        fee: '12',
        lastLedgerSequence: 7125358,
        flags: 0,
      );

      expect(payment.toJson(), {
        'TransactionType': 'Payment',
        'Account': 'rSender...',
        'Destination': 'rReceiver...',
        'Amount': '10000000',
        'DestinationTag': 12345,
        'Sequence': 6,
        'Fee': '12',
        'LastLedgerSequence': 7125358,
        'Flags': 0,
      });
    });
  });

  group('XrplPayment.copyWith', () {
    test('replaces only the given fields, keeping the rest unchanged', () {
      const original = XrplPayment(
        account: 'rSender...',
        destination: 'rReceiver...',
        amountDrops: '10000000',
        destinationTag: 999,
      );

      final filled = original.copyWith(
        sequence: 6,
        fee: '12',
        lastLedgerSequence: 7125358,
      );

      expect(filled.account, original.account);
      expect(filled.destination, original.destination);
      expect(filled.amountDrops, original.amountDrops);
      expect(filled.destinationTag, original.destinationTag);
      expect(filled.sequence, 6);
      expect(filled.fee, '12');
      expect(filled.lastLedgerSequence, 7125358);
    });

    test('does not mutate the original instance', () {
      final original = const XrplPayment(
        account: 'rSender...',
        destination: 'rReceiver...',
        amountDrops: '10000000',
      )..copyWith(sequence: 6);

      expect(original.sequence, isNull);
    });
  });
}
