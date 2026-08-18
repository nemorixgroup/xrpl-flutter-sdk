import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_endpoint.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_queries.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_key_algorithm.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_connection_exception.dart';
import 'package:xrpl_flutter_sdk/src/wallet/xrpl_wallet.dart';

// Integration test: calls serverInfo() and accountInfo() against the
// real public Testnet server. Kept in test/src/ alongside
// xrpl_connection_integration_test.dart, apart from any pure unit
// tests for this file, per this SDK's convention for network-dependent
// tests.
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
}
