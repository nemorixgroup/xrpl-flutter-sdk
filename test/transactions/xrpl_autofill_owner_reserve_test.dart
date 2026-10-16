import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_endpoint.dart';
import 'package:xrpl_flutter_sdk/src/transactions/models/xrpl_amm_create.dart';
import 'package:xrpl_flutter_sdk/src/transactions/values/xrpl_currency_amount.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_autofill.dart';

void main() {
  group('autofill with an owner-reserve-cost transaction', () {
    test(
      'keeps an explicit fee and never touches the network when every '
      'field is already set',
      () async {
        // A connection that was never connect()-ed: if autofill tried
        // to look up the owner reserve (or anything else) here,
        // XrplConnection.request would throw "not connected." A
        // completed call is proof the network was never touched.
        final connection = XrplConnection(XrplEndpoint.testnet);

        final tx = XrplAmmCreate(
          account: 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe',
          amount: const XrplCurrencyAmount.xrp('10000000'),
          amount2: const XrplCurrencyAmount.issued(
            currency: 'TST',
            issuer: 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd',
            value: '25',
          ),
          tradingFee: 500,
          sequence: 5,
          fee: '250000',
          lastLedgerSequence: 1000000,
        );

        final result = await autofill(connection, tx);

        expect(result.fee, '250000');
        expect(result.sequence, 5);
        expect(result.lastLedgerSequence, 1000000);
      },
    );
  });
}
