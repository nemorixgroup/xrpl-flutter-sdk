// Phase 3 - 0.2.3-dev: real-time subscription streams.
//
// Full technical decisions:
// https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-3/subscription-streams

import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

/// Subscribing pushes events to the SDK as they happen, instead of
/// polling with repeated request() calls. Each stream is typed
/// separately (ledgerEvents, transactionEvents, etc.) so there's no
/// manual "type" field checking required.
Future<void> subscriptionsExample() async {
  final connection = XrplConnection(XrplEndpoint.testnet);
  await connection.connect();

  await subscribeToLedger(connection);

  print('Waiting for the next ledger to close...');
  final event = await connection.ledgerEvents.first;
  print('New ledger closed: ${event['ledger_index']}');

  await unsubscribeFromLedger(connection);
  await connection.disconnect();
}
