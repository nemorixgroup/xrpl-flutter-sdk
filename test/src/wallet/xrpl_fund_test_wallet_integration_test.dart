import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_endpoint.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_queries.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_key_algorithm.dart';
import 'package:xrpl_flutter_sdk/src/wallet/xrpl_fund_test_wallet.dart';
import 'package:xrpl_flutter_sdk/src/wallet/xrpl_wallet.dart';

// Integration test: calls the real public Testnet Faucet and then
// verifies the funded account via a real accountInfo query. Kept
// alongside the other test/src/ integration files, per this SDK's
// convention for network-dependent tests.
//
// Reuses a fixed, already-funded wallet (restored from its seed)
// instead of generating a brand-new one on every run - the Faucet
// simply tops up the same account each time, rather than this SDK's
// test suite creating an ever-growing pile of one-off funded
// accounts on the public Testnet.
void main() {
  group('fundTestWallet against the real public Testnet Faucet', () {
    test(
        're-funds an existing wallet, confirmed by a real, non-zero '
        'balance', () async {
      // fundTestWallet(XrplEndpoint.testnet) without the `wallet`
      // parameter would generate a brand-new wallet every time - here
      // we deliberately pass `wallet` to reuse and top up the same
      // account on every run, instead of creating an ever-growing
      // pile of one-off funded accounts on the public Testnet.
      final existingWallet = await XrplWallet.fromSeed(
        'sEd7uJhbtp6miUCRSY8ioGeqvFBYcpi',
        algorithm: XrplKeyAlgorithm.ed25519,
      );

      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();

      // fundTestWallet(connection) without the `wallet` parameter
      // would generate a brand-new wallet every time - here we
      // deliberately pass `wallet` to reuse and top up the same
      // account on every run, instead of creating an ever-growing
      // pile of one-off funded accounts on the public Testnet.
      final wallet = await fundTestWallet(connection, wallet: existingWallet);

      expect(wallet.classicAddress, existingWallet.classicAddress);

      final accountData = await accountInfo(connection, wallet.classicAddress);
      final balance = int.parse(accountData['Balance'] as String);

      expect(balance, greaterThan(0));

      await connection.disconnect();
    });
  });
}
