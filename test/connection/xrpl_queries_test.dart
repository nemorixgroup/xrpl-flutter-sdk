import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

// Unit tests for ripplePathFind's client-side validation only. These
// run before the function ever calls connection.request, so no real
// connection or server is needed here - a non-connected XrplConnection
// instance is enough. Success-path behavior (the actual server
// response shape) is covered separately in
// xrpl_queries_integration_test.dart against the real Testnet server.
void main() {
  group('ripplePathFind validation', () {
    final connection = XrplConnection(XrplEndpoint.testnet);

    test(
      'throws ArgumentError when sourceCurrencies and sendMax are both '
      'provided',
      () {
        expect(
          () => ripplePathFind(
            connection,
            sourceAccount: 'rSource',
            destinationAccount: 'rDestination',
            destinationAmount: const XrplCurrencyAmount.xrp('1000000'),
            sourceCurrencies: const [XrplSourceCurrency(currency: 'USD')],
            sendMax: const XrplCurrencyAmount.xrp('1000000'),
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'throws ArgumentError when sourceCurrencies has more than 18 '
      'entries',
      () {
        final tooMany = List.generate(
          19,
          (i) => XrplSourceCurrency(currency: 'C$i'),
        );

        expect(
          () => ripplePathFind(
            connection,
            sourceAccount: 'rSource',
            destinationAccount: 'rDestination',
            destinationAmount: const XrplCurrencyAmount.xrp('1000000'),
            sourceCurrencies: tooMany,
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'accepts exactly 18 sourceCurrencies entries without throwing '
      'for that reason',
      () async {
        final eighteen = List.generate(
          18,
          (i) => XrplSourceCurrency(currency: 'C$i'),
        );

        // The call still fails, since connection is never connected, but
        // confirming the failure is NOT an ArgumentError is enough to
        // show the 18-entry check itself did not fire.
        await expectLater(
          ripplePathFind(
            connection,
            sourceAccount: 'rSource',
            destinationAccount: 'rDestination',
            destinationAmount: const XrplCurrencyAmount.xrp('1000000'),
            sourceCurrencies: eighteen,
          ),
          throwsA(isNot(isA<ArgumentError>())),
        );
      },
    );

    test(
      'throws ArgumentError when destinationAmount is neither "-1" nor '
      'an XrplCurrencyAmount',
      () {
        expect(
          () => ripplePathFind(
            connection,
            sourceAccount: 'rSource',
            destinationAccount: 'rDestination',
            destinationAmount: 42,
          ),
          throwsArgumentError,
        );
      },
    );

    test('accepts the literal "-1" for destinationAmount', () async {
      await expectLater(
        ripplePathFind(
          connection,
          sourceAccount: 'rSource',
          destinationAccount: 'rDestination',
          destinationAmount: '-1',
          sendMax: const XrplCurrencyAmount.xrp('1000000'),
        ),
        throwsA(isNot(isA<ArgumentError>())),
      );
    });

    test(
      'throws ArgumentError when sendMax is neither "-1" nor an '
      'XrplCurrencyAmount',
      () {
        expect(
          () => ripplePathFind(
            connection,
            sourceAccount: 'rSource',
            destinationAccount: 'rDestination',
            destinationAmount: const XrplCurrencyAmount.xrp('1000000'),
            sendMax: 'not-a-valid-amount',
          ),
          throwsArgumentError,
        );
      },
    );
  });
}
