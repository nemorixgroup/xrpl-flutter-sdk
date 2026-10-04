import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

// Unit tests for the path_find helpers' client-side behavior only:
// argument validation and subscription-state handling. The connection
// is never opened, so any call that gets past validation fails with an
// XrplConnectionException ("Not connected"), which is how these tests
// tell "validation passed" apart from "validation rejected it".
// Behavior against the real server is covered separately in
// xrpl_path_find_integration_test.dart.
void main() {
  group('pathFindCreate validation', () {
    late XrplConnection connection;

    setUp(() {
      // A fresh connection per test, so the subscription flag never
      // leaks from one test into the next.
      connection = XrplConnection(XrplEndpoint.testnet);
    });

    test(
      'throws ArgumentError when destinationAmount is neither "-1" nor '
      'an XrplCurrencyAmount',
      () {
        expect(
          () => pathFindCreate(
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
        pathFindCreate(
          connection,
          sourceAccount: 'rSource',
          destinationAccount: 'rDestination',
          destinationAmount: '-1',
          sendMax: const XrplCurrencyAmount.xrp('1000000'),
        ),
        throwsA(isA<XrplConnectionException>()),
      );
    });

    test('throws ArgumentError when sendMax is the literal "-1"', () {
      expect(
        () => pathFindCreate(
          connection,
          sourceAccount: 'rSource',
          destinationAccount: 'rDestination',
          destinationAmount: const XrplCurrencyAmount.xrp('1000000'),
          sendMax: '-1',
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when sendMax is not an XrplCurrencyAmount', () {
      expect(
        () => pathFindCreate(
          connection,
          sourceAccount: 'rSource',
          destinationAccount: 'rDestination',
          destinationAmount: const XrplCurrencyAmount.xrp('1000000'),
          sendMax: 'not-a-valid-amount',
        ),
        throwsArgumentError,
      );
    });

    test('accepts a list of paths without throwing for that reason', () async {
      await expectLater(
        pathFindCreate(
          connection,
          sourceAccount: 'rSource',
          destinationAccount: 'rDestination',
          destinationAmount: const XrplCurrencyAmount.xrp('1000000'),
          paths: [
            XrplPath([XrplPathStep(currency: 'USD', issuer: 'rIssuer')]),
          ],
        ),
        throwsA(isA<XrplConnectionException>()),
      );
    });
  });

  group('pathFindCreate subscription state', () {
    late XrplConnection connection;

    setUp(() {
      connection = XrplConnection(XrplEndpoint.testnet);
    });

    test('starts with no active subscription', () {
      expect(connection.hasActivePathFindSubscription, isFalse);
    });

    test(
      'throws StateError when a subscription is already open and '
      'replaceExisting is false',
      () async {
        connection.markPathFindSubscriptionActive(active: true);

        await expectLater(
          pathFindCreate(
            connection,
            sourceAccount: 'rSource',
            destinationAccount: 'rDestination',
            destinationAmount: const XrplCurrencyAmount.xrp('1000000'),
          ),
          throwsStateError,
        );
      },
    );

    test(
      'does not throw StateError when replaceExisting is true',
      () async {
        connection.markPathFindSubscriptionActive(active: true);

        await expectLater(
          pathFindCreate(
            connection,
            sourceAccount: 'rSource',
            destinationAccount: 'rDestination',
            destinationAmount: const XrplCurrencyAmount.xrp('1000000'),
            replaceExisting: true,
          ),
          throwsA(isA<XrplConnectionException>()),
        );
      },
    );

    test(
      'does not throw StateError once the subscription is marked closed',
      () async {
        connection
          ..markPathFindSubscriptionActive(active: true)
          ..markPathFindSubscriptionActive(active: false);

        await expectLater(
          pathFindCreate(
            connection,
            sourceAccount: 'rSource',
            destinationAccount: 'rDestination',
            destinationAmount: const XrplCurrencyAmount.xrp('1000000'),
          ),
          throwsA(isA<XrplConnectionException>()),
        );
      },
    );

    test(
      'reports invalid amounts before the already-open StateError',
      () {
        connection.markPathFindSubscriptionActive(active: true);

        expect(
          () => pathFindCreate(
            connection,
            sourceAccount: 'rSource',
            destinationAccount: 'rDestination',
            destinationAmount: 42,
          ),
          throwsArgumentError,
        );
      },
    );
  });

  group('pathFindStatus and pathFindClose without a connection', () {
    late XrplConnection connection;

    setUp(() {
      connection = XrplConnection(XrplEndpoint.testnet);
    });

    test('pathFindStatus throws XrplConnectionException when not connected',
        () async {
      await expectLater(
        pathFindStatus(connection),
        throwsA(isA<XrplConnectionException>()),
      );
    });

    test('pathFindClose throws XrplConnectionException when not connected',
        () async {
      await expectLater(
        pathFindClose(connection),
        throwsA(isA<XrplConnectionException>()),
      );
    });

    test('a failed pathFindClose leaves the subscription flag unchanged',
        () async {
      connection.markPathFindSubscriptionActive(active: true);

      await expectLater(
        pathFindClose(connection),
        throwsA(isA<XrplConnectionException>()),
      );

      expect(connection.hasActivePathFindSubscription, isTrue);
    });
  });
}
