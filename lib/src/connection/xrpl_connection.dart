import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:xrpl_flutter_sdk/src/connection/xrpl_endpoint.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_connection_exception.dart';

/// A WebSocket connection to an XRPL server.
///
/// Everything built in Phases 1 and 2 is offline,
/// deterministic math with no notion of "connected" or
/// "disconnected." This is the first stateful piece of the SDK - it
/// holds a live, persistent connection to a real XRPL server, which
/// introduces failure modes none of the earlier code has (the server
/// can be unreachable, the connection can drop mid-session, requests
/// can time out). See [XrplConnectionException] for why those
/// failures are modeled as their own exception type, separate from
/// `XrplCryptoException`.
///
/// Uses `package:web_socket_channel` (maintained by the Dart team)
/// rather than `dart:io`'s `WebSocket`, so this class works
/// unmodified on mobile, desktop, and (in the future) web.
///
/// This class only manages the connection's lifecycle (connect,
/// disconnect, and whether it's currently open). Sending requests and
/// reading responses is handled separately, once a connection is
/// established.
///
/// See:
/// https://xrpl.org/docs/tutorials/get-started/get-started-http-websocket-apis
class XrplConnection {
  /// Creates a connection targeting the given [endpoint]. The
  /// connection is not opened until [connect] is called.
  XrplConnection(this.endpoint);

  /// Which XRPL network (and therefore which server) this connection
  /// targets.
  final XrplEndpoint endpoint;

  WebSocketChannel? _channel;

  /// Whether this connection currently has an open channel.
  ///
  /// This only reflects whether [connect] has been called and
  /// [disconnect] has not - it does not actively verify the
  /// underlying socket is still alive, since a dropped connection is
  /// only discovered when a send or receive actually fails.
  bool get isConnected => _channel != null;

  /// Opens the WebSocket connection to [endpoint].
  ///
  /// Throws an [XrplConnectionException] if a connection is already
  /// open, or if the underlying WebSocket fails to connect.
  ///
  /// Example:
  /// ```dart
  /// final connection = XrplConnection(XrplEndpoint.testnet);
  /// await connection.connect();
  /// ```
  Future<void> connect() async {
    if (isConnected) {
      throw const XrplConnectionException(
        'Already connected. Call disconnect() before connecting again.',
      );
    }

    try {
      // WebSocketChannel.connect() itself never throws for a bad
      // URL or unreachable host - failures only surface once the
      // channel is actually used (or via .ready below), so this try
      // block exists for that ready check, not the connect() call.
      final channel =
          WebSocketChannel.connect(Uri.parse(endpoint.websocketUrl));
      await channel.ready;
      _channel = channel;
    } catch (error) {
      throw XrplConnectionException(
        'Failed to connect to ${endpoint.websocketUrl}: $error',
      );
    }
  }

  /// Closes the WebSocket connection, if one is open.
  ///
  /// Safe to call even if not currently connected - this is a no-op
  /// in that case, rather than an error, since "make sure we're
  /// disconnected" is a reasonable thing to want regardless of the
  /// current state.
  ///
  /// Example:
  /// ```dart
  /// await connection.disconnect();
  /// ```
  Future<void> disconnect() async {
    final channel = _channel;
    if (channel == null) return;

    await channel.sink.close();
    _channel = null;
  }
}
