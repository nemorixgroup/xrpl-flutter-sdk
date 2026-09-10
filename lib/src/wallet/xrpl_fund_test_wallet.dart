import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_endpoint.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_queries.dart';
import 'package:xrpl_flutter_sdk/src/crypto/xrpl_key_algorithm.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_connection_exception.dart';
import 'package:xrpl_flutter_sdk/src/wallet/xrpl_wallet.dart';

/// Funds a wallet with test XRP using the official public Testnet or
/// Devnet Faucet, so it can be used in real transactions without
/// spending real money.
///
/// Why this exists: every prior use of a freshly generated wallet in
/// this SDK's own tests has had to work around the fact that the
/// account doesn't exist on the ledger yet (no `Sequence` to look up,
/// no balance to send from). This closes that gap directly, the same
/// way `xrpl.js`'s `Client.fundWallet` and `xrpl-py`'s
/// `generate_faucet_wallet` do.
///
/// If [wallet] is provided, the Faucet funds that exact address -
/// this SDK generates and keeps the private key itself, the Faucet
/// only ever sees the public address. If omitted, a new wallet is
/// generated using [algorithm] and funded.
///
/// Requires [connection] to already be open, and takes its target
/// network from `connection.endpoint`. This is more than just a
/// convenience: after the Faucet's HTTP response confirms the
/// funding request was accepted, this function actively polls
/// `accountInfo` on that same connection until the account genuinely
/// exists on a validated ledger, before returning. A real bug this
/// SDK hit confirms why this matters - the Faucet's HTTP response
/// only means the funding *request* was accepted, not that the
/// funding transaction has validated yet; sending a transaction
/// immediately from a wallet funded this way, without this wait, can
/// fail because the account doesn't genuinely exist yet from the
/// connected server's point of view. See
/// `docs-sdk/phase-4/submission/` for the full investigation.
///
/// There is no Mainnet Faucet, and there never will be - Mainnet XRP
/// has real value, so nothing gives it away for free. Calling this
/// with a Mainnet connection throws immediately, rather than
/// attempting a request that could only fail confusingly.
///
/// Throws an [XrplConnectionException] if `connection.endpoint` is
/// [XrplEndpoint.mainnet], if the Faucet request itself fails, or if
/// the funded account still hasn't appeared after a reasonable
/// number of confirmation attempts.
///
/// Example:
/// ```dart
/// final connection = XrplConnection(XrplEndpoint.testnet);
/// await connection.connect();
/// final wallet = await fundTestWallet(connection);
/// print(wallet.classicAddress); // funded and confirmed, ready to use
/// ```
///
/// See: https://xrpl.org/docs/tools/xrp-faucets
Future<XrplWallet> fundTestWallet(
  XrplConnection connection, {
  XrplWallet? wallet,
  XrplKeyAlgorithm algorithm = XrplKeyAlgorithm.ed25519,
}) async {
  final endpoint = connection.endpoint;
  if (endpoint == XrplEndpoint.mainnet) {
    throw const XrplConnectionException(
      'fundTestWallet is only available for testnet and devnet - '
      'there is no faucet for mainnet, since Mainnet XRP has real value.',
    );
  }

  final targetWallet =
      wallet ?? await XrplWallet.generate(algorithm: algorithm);

  final faucetUrl = endpoint == XrplEndpoint.testnet
      ? 'https://faucet.altnet.rippletest.net/accounts'
      : 'https://faucet.devnet.rippletest.net/accounts';

  final http.Response response;
  try {
    response = await http.post(
      Uri.parse(faucetUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'destination': targetWallet.classicAddress}),
    );
  } catch (error) {
    throw XrplConnectionException('Faucet request failed: $error');
  }

  if (response.statusCode != 200) {
    throw XrplConnectionException(
      'Faucet request failed with status ${response.statusCode}: '
      '${response.body}',
    );
  }

  // The Faucet's HTTP response only confirms the funding request was
  // accepted - not that the funding transaction has validated yet.
  // Poll accountInfo until the account genuinely exists, rather than
  // trusting the HTTP response alone.
  const maxAttempts = 15;
  const attemptDelay = Duration(seconds: 1);
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      await accountInfo(
        connection,
        targetWallet.classicAddress,
        ledgerIndex: 'validated',
      );
      return targetWallet;
    } on XrplConnectionException catch (error) {
      if (!error.message.contains('actNotFound')) rethrow;
      await Future<void>.delayed(attemptDelay);
    }
  }

  throw XrplConnectionException(
    'Faucet accepted the funding request for '
    '${targetWallet.classicAddress}, but the account did not appear '
    'on a validated ledger after $maxAttempts attempts.',
  );
}
