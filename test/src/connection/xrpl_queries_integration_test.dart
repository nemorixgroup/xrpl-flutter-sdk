import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

// Integration test: calls serverInfo(), accountInfo(), and
// ripplePathFind() against the real public Testnet server. Kept in
// test/src/ alongside xrpl_connection_integration_test.dart, apart from
// any pure unit tests for this file, per this SDK's convention for
// network-dependent tests.
void main() {
  group('serverInfo against the real public Testnet server', () {
    test('returns server status fields with expected shape', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      final info = await serverInfo(connection);

      expect(info['server_state'], isA<String>());
      expect(info['build_version'], isA<String>());
      expect(info['complete_ledgers'], isA<String>());

      await connection.disconnect();
    });

    test('counters: true still returns the same core fields', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      final info = await serverInfo(connection, counters: true);

      expect(info['server_state'], isA<String>());

      await connection.disconnect();
    });
  });

  group('accountInfo against the real public Testnet server', () {
    // ---- IMPORTANT ----
    // (0.2.3-dev or later): add a success-case test once this SDK
    // can fund a Testnet account (e.g. via the Testnet Faucet/Friendbot).
    // A hardcoded "known funded account" would be unreliable long-term,
    // since Testnet resets periodically - only the error case below is
    // stable enough to rely on indefinitely.

    test('a freshly generated, never-funded account returns actNotFound',
        () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      // A brand-new wallet's address is valid in format but almost
      // certainly has never existed on the ledger, making this a
      // stable way to exercise the error path without depending on
      // any specific account continuing to exist over time.
      final wallet = await XrplWallet.generate(
        algorithm: XrplKeyAlgorithm.ed25519,
      );

      await expectLater(
        accountInfo(connection, wallet.classicAddress),
        throwsA(isA<XrplConnectionException>()),
      );

      await connection.disconnect();
    });
  });

  group('ripplePathFind against the real public Testnet server', () {
    test(
      'returns a response shaped per the official specification, even '
      'when no path exists',
      () async {
        final connection = XrplConnection(XrplEndpoint.testnet);
        await connection.connect();

        // source_account must actually exist on the ledger (hold at
        // least the account reserve), or the server rejects the
        // request entirely with srcActNotFound instead of returning
        // alternatives: [] - confirmed against the real Testnet
        // server; see the "rejects an unfunded source_account" test
        // below for that case, and docs-sdk/phase-5/path-finding/ for
        // where this is written up.
        final source = await fundTestWallet(connection);
        final destination = await fundTestWallet(connection);

        final result = await ripplePathFind(
          connection,
          sourceAccount: source.classicAddress,
          destinationAccount: destination.classicAddress,
          destinationAmount: XrplCurrencyAmount.issued(
            currency: 'TST',
            issuer: destination.classicAddress,
            value: '1',
          ),
        );

        expect(result['destination_account'], destination.classicAddress);
        expect(result['alternatives'], isA<List<dynamic>>());
        // No real order book path exists between these two freshly
        // funded, unrelated accounts for a currency only one of them
        // issues.
        expect(result['alternatives'], isEmpty);

        await connection.disconnect();
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'rejects an unfunded source_account with srcActNotFound',
      () async {
        final connection = XrplConnection(XrplEndpoint.testnet);
        await connection.connect();

        final source = await XrplWallet.generate(
          algorithm: XrplKeyAlgorithm.ed25519,
        );
        final destination = await XrplWallet.generate(
          algorithm: XrplKeyAlgorithm.ed25519,
        );

        await expectLater(
          ripplePathFind(
            connection,
            sourceAccount: source.classicAddress,
            destinationAccount: destination.classicAddress,
            destinationAmount: const XrplCurrencyAmount.xrp('1000000'),
          ),
          throwsA(isA<XrplConnectionException>()),
        );

        await connection.disconnect();
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
