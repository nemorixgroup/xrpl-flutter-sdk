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

    test(
        'throws immediately if LastLedgerSequence has the wrong type, '
        'without attempting any network request', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);

      final wrongTypeSignedTx = <String, dynamic>{
        'TransactionType': 'Payment',
        'Account': 'rSomeAddress...',
        'Destination': 'rSomeOtherAddress...',
        'Amount': '10000000',
        'Sequence': 1,
        'Fee': '10',
        'SigningPubKey': 'ED...',
        'TxnSignature': 'AB...',
        'LastLedgerSequence': '1000000', // should be an int, not a String
      };

      await expectLater(
        submitAndWait(connection, wrongTypeSignedTx),
        throwsA(isA<XrplConnectionException>()),
      );
    });

    test(
        'throws immediately for a zero pollInterval, without '
        'attempting any network request', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);

      final signedTx = <String, dynamic>{
        'TransactionType': 'Payment',
        'Account': 'rSomeAddress...',
        'Destination': 'rSomeOtherAddress...',
        'Amount': '10000000',
        'Sequence': 1,
        'Fee': '10',
        'SigningPubKey': 'ED...',
        'TxnSignature': 'AB...',
        'LastLedgerSequence': 1000000,
      };

      await expectLater(
        submitAndWait(connection, signedTx, pollInterval: Duration.zero),
        throwsA(isA<XrplConnectionException>()),
      );
    });

    test(
        'throws immediately for a negative pollInterval, without '
        'attempting any network request', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);

      final signedTx = <String, dynamic>{
        'TransactionType': 'Payment',
        'Account': 'rSomeAddress...',
        'Destination': 'rSomeOtherAddress...',
        'Amount': '10000000',
        'Sequence': 1,
        'Fee': '10',
        'SigningPubKey': 'ED...',
        'TxnSignature': 'AB...',
        'LastLedgerSequence': 1000000,
      };

      await expectLater(
        submitAndWait(
          connection,
          signedTx,
          pollInterval: const Duration(seconds: -1),
        ),
        throwsA(isA<XrplConnectionException>()),
      );
    });
  });
}
