import 'dart:async';
import 'dart:convert';

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
/// Besides the connection lifecycle (connect, disconnect,
/// isConnected), this class exposes a single generic [request]
/// method that speaks XRPL's request/response protocol without
/// knowing anything about specific commands. Command-specific
/// helpers (like `accountInfo`, `serverInfo`) are built on top of
/// [request] elsewhere, rather than each reimplementing the same
/// send/match/receive plumbing.
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

  /// How long [request] waits for a matching response before giving
  /// up and throwing an [XrplConnectionException]. Chosen as a
  /// generous default for a live network call, not a value from any
  /// official specification (xrpl.org does not define one).
  static const Duration defaultRequestTimeout = Duration(seconds: 20);

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  // Every in-flight request is tracked here by the "id" it was sent
  // with, so the response (which echoes that same id) can be routed
  // back to the exact call that is waiting for it, even if several
  // requests are in flight over the same connection at once.
  final Map<int, Completer<Map<String, dynamic>>> _pendingRequests = {};
  int _nextRequestId = 1;

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
      // Start listening for incoming messages now, once, for the
      // lifetime of the connection - individual requests don't each
      // set up their own listener, they just register a Completer
      // and wait for this shared listener to resolve it.
      _subscription = channel.stream.listen(
        _handleIncomingMessage,
        onError: _handleStreamError,
        onDone: _handleStreamDone,
      );
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

    await _subscription?.cancel();
    _subscription = null;
    await channel.sink.close();
    _channel = null;

    // Any request still waiting for a response at this point will
    // never get one now that the connection is closed - fail them
    // explicitly instead of leaving their Futures pending forever.
    _failAllPendingRequests('Connection closed before a response arrived.');
  }

  /// Sends a single XRPL API request and returns its response.
  ///
  /// [command] is the XRPL method name (for example `"account_info"`
  /// or `"server_info"`), sent as the request's `command` field per
  /// the official request format. [params] are merged in alongside
  /// it - this method adds nothing XRPL-specific beyond the shared
  /// `id`/`command` envelope, so any current or future command can
  /// be sent through it.
  ///
  /// Throws an [XrplConnectionException] if not currently connected,
  /// if the request times out (see [defaultRequestTimeout]), or if
  /// the server's response has `"status": "error"`.
  ///
  /// Example:
  /// ```dart
  /// final response = await connection.request('server_info', {'counters': false});
  /// print(response['result']['info']['server_state']);
  /// ```
  Future<Map<String, dynamic>> request(
    String command, [
    Map<String, dynamic> params = const {},
  ]) async {
    final channel = _channel;
    if (channel == null) {
      throw const XrplConnectionException(
        'Not connected. Call connect() before sending a request.',
      );
    }

    // Each request gets its own id so its response - which the
    // server echoes the same id back on - can be matched to it, even
    // if other requests are in flight at the same time.
    final id = _nextRequestId++;
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[id] = completer;

    final requestPayload = <String, dynamic>{
      'id': id,
      'command': command,
      ...params,
    };
    channel.sink.add(jsonEncode(requestPayload));

    final response = await completer.future.timeout(
      defaultRequestTimeout,
      onTimeout: () {
        _pendingRequests.remove(id);
        throw XrplConnectionException(
          'Request "$command" (id $id) timed out after '
          '${defaultRequestTimeout.inSeconds}s.',
        );
      },
    );

    // Per the official response format, an error response still has
    // status/type/id like a success response, but status is "error"
    // and result is replaced by an error code - surface that as an
    // exception rather than handing back an error envelope silently.
    if (response['status'] == 'error') {
      throw XrplConnectionException(
        'Request "$command" failed: ${response['error']}',
      );
    }

    return response;
  }

  void _handleIncomingMessage(dynamic message) {
    final decoded = jsonDecode(message as String) as Map<String, dynamic>;
    final id = decoded['id'];
    if (id is! int) return; // Not a response we're tracking; ignore.

    final completer = _pendingRequests.remove(id);
    completer?.complete(decoded);
  }

  void _handleStreamError(Object error) {
    _failAllPendingRequests('Connection error: $error');
  }

  void _handleStreamDone() {
    _failAllPendingRequests('Connection closed before a response arrived.');
  }

  void _failAllPendingRequests(String message) {
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(XrplConnectionException(message));
      }
    }
    _pendingRequests.clear();
  }
}
