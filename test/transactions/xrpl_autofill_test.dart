import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_endpoint.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_connection_exception.dart';
import 'package:xrpl_flutter_sdk/src/transactions/models/xrpl_payment.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_autofill.dart';

void main() {
  group('autofill skip-lookup behavior', () {
    test(
        'never touches the network when sequence, fee, and '
        'lastLedgerSequence are all already provided', () async {
      // A connection that was never connect()-ed: if autofill tried
      // to call accountInfo or fee here, XrplConnection.request would
      // throw "not connected." A completed call with no exception is
      // proof the network was never touched, since every field this
      // transaction needs is already set.
      final connection = XrplConnection(XrplEndpoint.testnet);

      const payment = XrplPayment(
        account: 'rSomeAddress...',
        destination: 'rSomeOtherAddress...',
        amountDrops: '10000000',
        sequence: 5,
        fee: '12',
        lastLedgerSequence: 1000000,
      );

      final result = await autofill(connection, payment);

      expect(result.sequence, 5);
      expect(result.fee, '12');
      expect(result.lastLedgerSequence, 1000000);
    });
  });

  group('autofill ledgerOffset validation', () {
    test(
        'throws immediately for a negative ledgerOffset, without '
        'attempting any network request', () async {
      // Same "never touches the network" proof as above: a
      // never-connected connection would throw "not connected" if
      // autofill got far enough to call accountInfo/fee - so throwing
      // here instead confirms the ledgerOffset check runs first.
      final connection = XrplConnection(XrplEndpoint.testnet);

      const payment = XrplPayment(
        account: 'rSomeAddress...',
        destination: 'rSomeOtherAddress...',
        amountDrops: '10000000',
      );

      await expectLater(
        autofill(connection, payment, ledgerOffset: -1),
        throwsA(isA<XrplConnectionException>()),
      );
    });

    test('accepts ledgerOffset: 0 without throwing (skip-lookup path)',
        () async {
      final connection = XrplConnection(XrplEndpoint.testnet);

      const payment = XrplPayment(
        account: 'rSomeAddress...',
        destination: 'rSomeOtherAddress...',
        amountDrops: '10000000',
        sequence: 5,
        fee: '12',
        lastLedgerSequence: 1000000,
      );

      await expectLater(
        autofill(connection, payment, ledgerOffset: 0),
        completes,
      );
    });
  });
}
