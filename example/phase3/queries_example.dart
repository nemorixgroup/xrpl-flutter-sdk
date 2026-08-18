// Phase 3 - 0.2.2-dev: JSON-RPC requests and account/server queries.
//
// Full technical decisions:
// https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-3/requests-and-queries

import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

/// serverInfo and accountInfo are built on top of the generic
/// XrplConnection.request(), each unwrapping the response envelope
/// down to just its useful inner data.
Future<void> queriesExample() async {
  final connection = XrplConnection(XrplEndpoint.testnet);
  await connection.connect();

  final info = await serverInfo(connection);
  print('Server state: ${info['server_state']}');

  // A freshly generated wallet has never been funded, so account_info
  // is expected to fail - this demonstrates the error path.
  final wallet = await XrplWallet.generate(
    algorithm: XrplKeyAlgorithm.ed25519,
  );
  try {
    await accountInfo(connection, wallet.classicAddress);
  } on XrplConnectionException catch (e) {
    print('Expected error for an unfunded account: ${e.message}');
  }

  await connection.disconnect();
}
