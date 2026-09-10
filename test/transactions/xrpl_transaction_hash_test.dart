import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_transaction_hash.dart';

void main() {
  group('transactionHash against an independently computed vector', () {
    // Chained from the exact same Ed25519 signing scenario already
    // verified end-to-end in xrpl_signer_test.dart. The expected hash
    // was independently computed via a standalone Python script,
    // using the officially confirmed "signed transaction" hash prefix
    // (0x54584E00), distinct from the signing prefix (0x53545800).
    test('matches the independently computed transaction hash', () {
      final signedJson = <String, dynamic>{
        'TransactionType': 'Payment',
        'Account': 'rG31cLyErnqeVj2eomEjBZtq7PYaupGYzL',
        'Destination': 'rG31cLyErnqeVj2eomEjBZtq7PYaupGYzL',
        'Amount': '5000000',
        'Sequence': 1,
        'Fee': '10',
        'SigningPubKey':
            'EDA57EBBCB502C2009EFE17229E8DC865DCCB192C52D7888D624DC9EBADDB815F0',
        'TxnSignature':
            'A8ADE756C292305CB6FAA8ACD671C0E637E9474530C8C7D8F26268A299BA87'
                '4A12EE40E231BC47F3A160F6A0310B1B90CE35C67A6EE28C7916DD335650FB9E02',
      };

      final hash = transactionHash(signedJson);

      expect(
        hash,
        '18989FDEEC53E8C1178450D8EDCED432598CCF92A7CD89F726AA7BE204E5478C',
      );
    });

    test('is deterministic for the same input', () {
      final signedJson = <String, dynamic>{
        'TransactionType': 'Payment',
        'Account': 'rG31cLyErnqeVj2eomEjBZtq7PYaupGYzL',
        'Destination': 'rG31cLyErnqeVj2eomEjBZtq7PYaupGYzL',
        'Amount': '5000000',
        'Sequence': 1,
        'Fee': '10',
        'SigningPubKey':
            'EDA57EBBCB502C2009EFE17229E8DC865DCCB192C52D7888D624DC9EBADDB815F0',
        'TxnSignature':
            'A8ADE756C292305CB6FAA8ACD671C0E637E9474530C8C7D8F26268A299BA87'
                '4A12EE40E231BC47F3A160F6A0310B1B90CE35C67A6EE28C7916DD335650FB9E02',
      };

      expect(transactionHash(signedJson), transactionHash(signedJson));
    });

    test('produces exactly 64 uppercase hex characters (32 bytes)', () {
      final signedJson = <String, dynamic>{
        'TransactionType': 'Payment',
        'Account': 'rG31cLyErnqeVj2eomEjBZtq7PYaupGYzL',
        'Destination': 'rG31cLyErnqeVj2eomEjBZtq7PYaupGYzL',
        'Amount': '5000000',
        'Sequence': 1,
        'Fee': '10',
        'SigningPubKey':
            'EDA57EBBCB502C2009EFE17229E8DC865DCCB192C52D7888D624DC9EBADDB815F0',
        'TxnSignature':
            'A8ADE756C292305CB6FAA8ACD671C0E637E9474530C8C7D8F26268A299BA87'
                '4A12EE40E231BC47F3A160F6A0310B1B90CE35C67A6EE28C7916DD335650FB9E02',
      };

      final hash = transactionHash(signedJson);
      expect(hash.length, 64);
      expect(hash, hash.toUpperCase());
    });
  });
}
