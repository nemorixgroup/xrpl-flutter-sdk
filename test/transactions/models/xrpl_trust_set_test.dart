import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/transactions/models/xrpl_trust_set.dart';

void main() {
  group('XrplTrustSet.toJson', () {
    test('includes only the required fields when nothing else is set', () {
      const trustSet = XrplTrustSet(
        account: 'rHolder...',
        currency: 'USD',
        issuer: 'rIssuer...',
        limitValue: '1000',
      );

      expect(trustSet.toJson(), {
        'TransactionType': 'TrustSet',
        'Account': 'rHolder...',
        'LimitAmount': {
          'currency': 'USD',
          'issuer': 'rIssuer...',
          'value': '1000',
        },
      });
    });

    test('includes optional fields only when they are set', () {
      const trustSet = XrplTrustSet(
        account: 'rHolder...',
        currency: 'USD',
        issuer: 'rIssuer...',
        limitValue: '1000',
        sequence: 12,
        fee: '12',
        lastLedgerSequence: 8007750,
        flags: 262144,
      );

      expect(trustSet.toJson(), {
        'TransactionType': 'TrustSet',
        'Account': 'rHolder...',
        'LimitAmount': {
          'currency': 'USD',
          'issuer': 'rIssuer...',
          'value': '1000',
        },
        'Sequence': 12,
        'Fee': '12',
        'LastLedgerSequence': 8007750,
        'Flags': 262144,
      });
    });
  });

  group('XrplTrustSet.copyWith', () {
    test('replaces only the given fields, keeping the rest unchanged', () {
      const original = XrplTrustSet(
        account: 'rHolder...',
        currency: 'USD',
        issuer: 'rIssuer...',
        limitValue: '1000',
      );

      final filled = original.copyWith(
        sequence: 12,
        fee: '12',
        lastLedgerSequence: 8007750,
      );

      expect(filled.account, original.account);
      expect(filled.currency, original.currency);
      expect(filled.issuer, original.issuer);
      expect(filled.limitValue, original.limitValue);
      expect(filled.sequence, 12);
      expect(filled.fee, '12');
      expect(filled.lastLedgerSequence, 8007750);
    });

    test('does not mutate the original instance', () {
      final original = const XrplTrustSet(
        account: 'rHolder...',
        currency: 'USD',
        issuer: 'rIssuer...',
        limitValue: '1000',
      )..copyWith(sequence: 12);

      expect(original.sequence, isNull);
    });
  });
}
