// Phase 3 - 0.2.1-dev: connection lifecycle.
//
// Full technical decisions:
// https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-3/connection-lifecycle

import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

/// This first piece of Phase 3 only manages opening and closing a
/// real WebSocket connection to an XRPL server - sending requests
/// comes in the next release.
Future<void> connectionExample() async {
  final connection = XrplConnection(XrplEndpoint.testnet);
  print('Connected before connect(): ${connection.isConnected}'); // false

  await connection.connect();
  print('Connected after connect(): ${connection.isConnected}'); // true

  // Connecting again without disconnecting first is rejected.
  try {
    await connection.connect();
  } on XrplConnectionException catch (e) {
    print('Expected validation error: ${e.message}');
  }

  await connection.disconnect();
  print('Connected after disconnect(): ${connection.isConnected}'); // false
}
