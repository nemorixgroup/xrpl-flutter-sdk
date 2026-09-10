import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_endpoint.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_connection_exception.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_submit_and_wait.dart';

void main() {
  group('submitAndWait validation', () {
    test(
        'throws immediately if LastLedgerSequence is missing, without '
        'attempting any network request', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);

      final incompleteSignedTx = <String, dynamic>{
        'TransactionType': 'Payment',
        'Account': 'rSomeAddress...',
        'Destination': 'rSomeOtherAddress...',
        'Amount': '10000000',
        'Sequence': 1,
        'Fee': '10',
        'SigningPubKey': 'ED...',
        'TxnSignature': 'AB...',
        // LastLedgerSequence deliberately omitted.
      };

      await expectLater(
        submitAndWait(connection, incompleteSignedTx),
        throwsA(isA<XrplConnectionException>()),
      );
    });
  });
}
