import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/transactions/binary/xrpl_field_definitions.dart';

// This test is deliberately a "snapshot" check: it asserts each
// XrplFieldDefinitions value matches exactly what
// scripts/regenerate_field_definitions.dart printed when run against
// the live public Testnet server's server_definitions response. If
// this test ever fails after hand-editing xrpl_field_definitions.dart,
// that is a signal the values were edited by hand instead of
// regenerated - re-run the script and update both together.
void main() {
  group('XrplFieldDefinitions', () {
    test('transactionType matches the generated value', () {
      expect(XrplFieldDefinitions.transactionType.typeCode, 1);
      expect(XrplFieldDefinitions.transactionType.fieldCode, 2);
      expect(XrplFieldDefinitions.transactionType.fieldIdBytes, [0x12]);
      expect(XrplFieldDefinitions.transactionType.isVLEncoded, isFalse);
    });

    test('flags matches the generated value', () {
      expect(XrplFieldDefinitions.transactionType.typeCode, 1);
      expect(XrplFieldDefinitions.transactionType.fieldCode, 2);
      expect(XrplFieldDefinitions.flags.fieldIdBytes, [0x22]);
      expect(XrplFieldDefinitions.flags.isVLEncoded, isFalse);
    });

    test('sequence matches the generated value', () {
      expect(XrplFieldDefinitions.transactionType.typeCode, 1);
      expect(XrplFieldDefinitions.transactionType.fieldCode, 2);
      expect(XrplFieldDefinitions.sequence.fieldIdBytes, [0x24]);
      expect(XrplFieldDefinitions.sequence.isVLEncoded, isFalse);
    });

    test('destinationTag matches the generated value', () {
      expect(XrplFieldDefinitions.transactionType.typeCode, 1);
      expect(XrplFieldDefinitions.transactionType.fieldCode, 2);
      expect(XrplFieldDefinitions.destinationTag.fieldIdBytes, [0x2E]);
      expect(XrplFieldDefinitions.destinationTag.isVLEncoded, isFalse);
    });

    test('lastLedgerSequence matches the generated value (2 bytes)', () {
      expect(XrplFieldDefinitions.transactionType.typeCode, 1);
      expect(XrplFieldDefinitions.transactionType.fieldCode, 2);
      expect(
        XrplFieldDefinitions.lastLedgerSequence.fieldIdBytes,
        [0x20, 0x1B],
      );
      expect(XrplFieldDefinitions.lastLedgerSequence.isVLEncoded, isFalse);
    });

    test('signingPubKey matches the generated value', () {
      expect(XrplFieldDefinitions.transactionType.typeCode, 1);
      expect(XrplFieldDefinitions.transactionType.fieldCode, 2);
      expect(XrplFieldDefinitions.signingPubKey.fieldIdBytes, [0x73]);
      expect(XrplFieldDefinitions.signingPubKey.isVLEncoded, isTrue);
    });

    test('txnSignature matches the generated value', () {
      expect(XrplFieldDefinitions.transactionType.typeCode, 1);
      expect(XrplFieldDefinitions.transactionType.fieldCode, 2);
      expect(XrplFieldDefinitions.txnSignature.fieldIdBytes, [0x74]);
      expect(XrplFieldDefinitions.txnSignature.isVLEncoded, isTrue);
    });

    test('fee matches the generated value', () {
      expect(XrplFieldDefinitions.transactionType.typeCode, 1);
      expect(XrplFieldDefinitions.transactionType.fieldCode, 2);
      expect(XrplFieldDefinitions.fee.fieldIdBytes, [0x68]);
      expect(XrplFieldDefinitions.fee.isVLEncoded, isFalse);
    });

    test('amount matches the generated value', () {
      expect(XrplFieldDefinitions.transactionType.typeCode, 1);
      expect(XrplFieldDefinitions.transactionType.fieldCode, 2);
      expect(XrplFieldDefinitions.amount.fieldIdBytes, [0x61]);
      expect(XrplFieldDefinitions.amount.isVLEncoded, isFalse);
    });

    test('account matches the generated value', () {
      expect(XrplFieldDefinitions.transactionType.typeCode, 1);
      expect(XrplFieldDefinitions.transactionType.fieldCode, 2);
      expect(XrplFieldDefinitions.account.fieldIdBytes, [0x81]);
      expect(XrplFieldDefinitions.account.isVLEncoded, isTrue);
    });

    test('destination matches the generated value', () {
      expect(XrplFieldDefinitions.transactionType.typeCode, 1);
      expect(XrplFieldDefinitions.transactionType.fieldCode, 2);
      expect(XrplFieldDefinitions.destination.fieldIdBytes, [0x83]);
      expect(XrplFieldDefinitions.destination.isVLEncoded, isTrue);
    });

    test('limitAmount matches the generated value', () {
      expect(XrplFieldDefinitions.transactionType.typeCode, 1);
      expect(XrplFieldDefinitions.transactionType.fieldCode, 2);
      expect(XrplFieldDefinitions.limitAmount.fieldIdBytes, [0x63]);
      expect(XrplFieldDefinitions.limitAmount.isVLEncoded, isFalse);
    });
  });

  group('XrplTransactionTypeCode', () {
    test('payment matches the generated value', () {
      expect(XrplFieldDefinitions.transactionType.typeCode, 1);
      expect(XrplFieldDefinitions.transactionType.fieldCode, 2);
      expect(XrplTransactionTypeCode.payment, 0);
    });

    test('trustSet matches the generated value', () {
      expect(XrplFieldDefinitions.transactionType.typeCode, 1);
      expect(XrplFieldDefinitions.transactionType.fieldCode, 2);
      expect(XrplTransactionTypeCode.trustSet, 20);
    });
  });
}
