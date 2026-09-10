import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:xrpl_flutter_sdk/src/connection/xrpl_endpoint.dart';
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
/// There is no Mainnet Faucet, and there never will be - Mainnet XRP
/// has real value, so nothing gives it away for free. Calling this
/// with [XrplEndpoint.mainnet] throws immediately, rather than
/// attempting a request that could only fail confusingly.
///
/// Throws an [XrplConnectionException] if [endpoint] is
/// [XrplEndpoint.mainnet], or if the Faucet request itself fails.
///
/// Example:
/// ```dart
/// final wallet = await fundTestWallet(XrplEndpoint.testnet);
/// print(wallet.classicAddress); // funded, ready to use
/// ```
///
/// See: https://xrpl.org/docs/tools/xrp-faucets
Future<XrplWallet> fundTestWallet(
  XrplEndpoint endpoint, {
  XrplWallet? wallet,
  XrplKeyAlgorithm algorithm = XrplKeyAlgorithm.ed25519,
}) async {
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

  return targetWallet;
}
