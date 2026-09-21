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
      expect(XrplFieldDefinitions.flags.typeCode, 2);
      expect(XrplFieldDefinitions.flags.fieldCode, 2);
      expect(XrplFieldDefinitions.flags.fieldIdBytes, [0x22]);
      expect(XrplFieldDefinitions.flags.isVLEncoded, isFalse);
    });

    test('sequence matches the generated value', () {
      expect(XrplFieldDefinitions.sequence.typeCode, 2);
      expect(XrplFieldDefinitions.sequence.fieldCode, 4);
      expect(XrplFieldDefinitions.sequence.fieldIdBytes, [0x24]);
      expect(XrplFieldDefinitions.sequence.isVLEncoded, isFalse);
    });

    test('destinationTag matches the generated value', () {
      expect(XrplFieldDefinitions.destinationTag.typeCode, 2);
      expect(XrplFieldDefinitions.destinationTag.fieldCode, 14);
      expect(XrplFieldDefinitions.destinationTag.fieldIdBytes, [0x2E]);
      expect(XrplFieldDefinitions.destinationTag.isVLEncoded, isFalse);
    });

    test('lastLedgerSequence matches the generated value (2 bytes)', () {
      expect(XrplFieldDefinitions.lastLedgerSequence.typeCode, 2);
      expect(XrplFieldDefinitions.lastLedgerSequence.fieldCode, 27);
      expect(
        XrplFieldDefinitions.lastLedgerSequence.fieldIdBytes,
        [0x20, 0x1B],
      );
      expect(XrplFieldDefinitions.lastLedgerSequence.isVLEncoded, isFalse);
    });

    test('signingPubKey matches the generated value', () {
      expect(XrplFieldDefinitions.signingPubKey.typeCode, 7);
      expect(XrplFieldDefinitions.signingPubKey.fieldCode, 3);
      expect(XrplFieldDefinitions.signingPubKey.fieldIdBytes, [0x73]);
      expect(XrplFieldDefinitions.signingPubKey.isVLEncoded, isTrue);
    });

    test('txnSignature matches the generated value', () {
      expect(XrplFieldDefinitions.txnSignature.typeCode, 7);
      expect(XrplFieldDefinitions.txnSignature.fieldCode, 4);
      expect(XrplFieldDefinitions.txnSignature.fieldIdBytes, [0x74]);
      expect(XrplFieldDefinitions.txnSignature.isVLEncoded, isTrue);
    });

    test('fee matches the generated value', () {
      expect(XrplFieldDefinitions.fee.typeCode, 6);
      expect(XrplFieldDefinitions.fee.fieldCode, 8);
      expect(XrplFieldDefinitions.fee.fieldIdBytes, [0x68]);
      expect(XrplFieldDefinitions.fee.isVLEncoded, isFalse);
    });

    test('amount matches the generated value', () {
      expect(XrplFieldDefinitions.amount.typeCode, 6);
      expect(XrplFieldDefinitions.amount.fieldCode, 1);
      expect(XrplFieldDefinitions.amount.fieldIdBytes, [0x61]);
      expect(XrplFieldDefinitions.amount.isVLEncoded, isFalse);
    });

    test('account matches the generated value', () {
      expect(XrplFieldDefinitions.account.typeCode, 8);
      expect(XrplFieldDefinitions.account.fieldCode, 1);
      expect(XrplFieldDefinitions.account.fieldIdBytes, [0x81]);
      expect(XrplFieldDefinitions.account.isVLEncoded, isTrue);
    });

    test('destination matches the generated value', () {
      expect(XrplFieldDefinitions.destination.typeCode, 8);
      expect(XrplFieldDefinitions.destination.fieldCode, 3);
      expect(XrplFieldDefinitions.destination.fieldIdBytes, [0x83]);
      expect(XrplFieldDefinitions.destination.isVLEncoded, isTrue);
    });

    test('limitAmount matches the generated value', () {
      expect(XrplFieldDefinitions.limitAmount.typeCode, 6);
      expect(XrplFieldDefinitions.limitAmount.fieldCode, 3);
      expect(XrplFieldDefinitions.limitAmount.fieldIdBytes, [0x63]);
      expect(XrplFieldDefinitions.limitAmount.isVLEncoded, isFalse);
    });

    test('takerGets matches the generated value', () {
      expect(XrplFieldDefinitions.takerGets.typeCode, 6);
      expect(XrplFieldDefinitions.takerGets.fieldCode, 5);
      expect(XrplFieldDefinitions.takerGets.fieldIdBytes, [0x65]);
      expect(XrplFieldDefinitions.takerGets.isVLEncoded, isFalse);
    });

    test('takerPays matches the generated value', () {
      expect(XrplFieldDefinitions.takerPays.typeCode, 6);
      expect(XrplFieldDefinitions.takerPays.fieldCode, 4);
      expect(XrplFieldDefinitions.takerPays.fieldIdBytes, [0x64]);
      expect(XrplFieldDefinitions.takerPays.isVLEncoded, isFalse);
    });

    test('expiration matches the generated value', () {
      expect(XrplFieldDefinitions.expiration.typeCode, 2);
      expect(XrplFieldDefinitions.expiration.fieldCode, 10);
      expect(XrplFieldDefinitions.expiration.fieldIdBytes, [0x2A]);
      expect(XrplFieldDefinitions.expiration.isVLEncoded, isFalse);
    });

    test('offerSequence matches the generated value (2 bytes)', () {
      expect(XrplFieldDefinitions.offerSequence.typeCode, 2);
      expect(XrplFieldDefinitions.offerSequence.fieldCode, 25);
      expect(
        XrplFieldDefinitions.offerSequence.fieldIdBytes,
        [0x20, 0x19],
      );
      expect(XrplFieldDefinitions.offerSequence.isVLEncoded, isFalse);
    });
  });

  group('XrplTransactionTypeCode', () {
    test('payment matches the generated value', () {
      expect(XrplTransactionTypeCode.payment, 0);
    });

    test('trustSet matches the generated value', () {
      expect(XrplTransactionTypeCode.trustSet, 20);
    });

    test('offerCreate matches the generated value', () {
      expect(XrplTransactionTypeCode.offerCreate, 7);
    });

    test('offerCancel matches the generated value', () {
      expect(XrplTransactionTypeCode.offerCancel, 8);
    });
  });
}
