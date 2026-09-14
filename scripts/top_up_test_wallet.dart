// Prints are this maintenance script's actual output - it's a
// command-line tool, not part of the public SDK, so avoid_print
// doesn't apply here.
// ignore_for_file: avoid_print

// Internal maintenance tool - NOT part of the public SDK API.
//
// Repeatedly funds an existing Testnet wallet via the official Faucet
// until its balance reaches a target amount. Useful for topping up
// one of this SDK's reusable test wallets, rather than generating yet
// another one-off funded account.
//
// The Faucet delivers a fixed amount per request (100 XRP as of this
// writing) rather than accepting a custom amount, so reaching a
// larger target means calling it multiple times with a short delay
// between requests.
//
// Usage:
//   dart run scripts/top_up_test_wallet.dart <seed> <algorithm> <targetXrp>
//
// Example:
//   dart run scripts/top_up_test_wallet.dart sEd7Z2q98nHustDyrsuieeEVipu4nMi ed25519 1000
//
// You can verify the resulting balance in a browser afterward, at:
//   https://testnet.xrpl.org/accounts/<the wallet's classicAddress,
//   printed by this script>

import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

void main(List<String> args) async {
  if (args.length != 3) {
    print(
      'Usage: dart run scripts/top_up_test_wallet.dart <seed> <algorithm> <targetXrp>',
    );
    return;
  }

  final seed = args[0];
  final algorithm = args[1] == 'secp256k1'
      ? XrplKeyAlgorithm.secp256k1
      : XrplKeyAlgorithm.ed25519;
  final targetDrops = int.parse(args[2]) * 1000000;

  final wallet = await XrplWallet.fromSeed(seed, algorithm: algorithm);
  print('Topping up ${wallet.classicAddress} to at least '
      '${args[2]} XRP...');

  final connection = XrplConnection(XrplEndpoint.testnet);
  await connection.connect();

  const maxAttempts = 20;
  const delayBetweenRequests = Duration(seconds: 3);

  var reachedTarget = false;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final accountData = await accountInfo(
      connection,
      wallet.classicAddress,
      ledgerIndex: 'validated',
    );
    final currentBalance = int.parse(accountData['Balance'] as String);
    print('Current balance: ${currentBalance / 1000000} XRP');

    if (currentBalance >= targetDrops) {
      print('Target reached.');
      reachedTarget = true;
      break;
    }

    await fundTestWallet(connection, wallet: wallet);
    await Future<void>.delayed(delayBetweenRequests);
  }

  if (!reachedTarget) {
    print(
      'Target not reached after $maxAttempts attempts - run the script '
      'again to continue topping up.',
    );
  }

  await connection.disconnect();
}
