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
/// It also exposes typed event streams ([ledgerEvents],
/// [transactionEvents], [validationEvents], [serverEvents]) for XRPL
/// subscription push messages. Per the official specification, these
/// arrive as a genuinely different kind of message from request
/// responses: a response echoes back the `id` the request was sent
/// with, while a subscription event has no `id` at all and is
/// instead identified by a `type` field (`"ledgerClosed"`,
/// `"transaction"`, and so on). Splitting events into one stream per
/// type - rather than a single generic stream the caller filters by
/// `type` themselves - removes an entire class of typo-prone,
/// silently-ignored-on-mismatch string comparisons from calling code.
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

  // One broadcast controller per subscription event type this SDK
  // currently supports. Created once at construction (not per
  // connect() call) so a caller's existing .listen() subscriptions
  // keep working across a disconnect/reconnect, rather than being
  // silently invalidated by a fresh controller each time.
  final StreamController<Map<String, dynamic>> _ledgerEventsController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _transactionEventsController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _validationEventsController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _serverEventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Whether this connection currently has an open channel.
  ///
  /// This only reflects whether [connect] has been called and
  /// [disconnect] has not - it does not actively verify the
  /// underlying socket is still alive, since a dropped connection is
  /// only discovered when a send or receive actually fails.
  bool get isConnected => _channel != null;

  /// Emits a message every time the server's `ledger` stream sends a
  /// `ledgerClosed` event (a new ledger version was validated).
  /// Requires subscribing first - see the `subscribeToLedger` helper.
  Stream<Map<String, dynamic>> get ledgerEvents =>
      _ledgerEventsController.stream;

  /// Emits a message every time the server's `transactions` (or
  /// `transactions_proposed`) stream sends a `transaction` event.
  /// Requires subscribing first.
  Stream<Map<String, dynamic>> get transactionEvents =>
      _transactionEventsController.stream;

  /// Emits a message every time the server's `validations` stream
  /// sends a `validationReceived` event. Requires subscribing first.
  Stream<Map<String, dynamic>> get validationEvents =>
      _validationEventsController.stream;

  /// Emits a message every time the server's `server` stream sends a
  /// `serverStatus` event. Requires subscribing first.
  Stream<Map<String, dynamic>> get serverEvents =>
      _serverEventsController.stream;

  /// Opens the WebSocket connection to [endpoint].
  ///
  /// Throws an [XrplConnectionException] if a connection is already
  /// open, or if the underlying WebSocket fails to connect.
  ///
  /// Note: XRPL subscriptions are tied to the specific WebSocket
  /// connection they were made on, not remembered by the server
  /// across reconnects. This class does not reconnect automatically,
  /// so any active subscriptions need to be re-established (via
  /// `subscribeToLedger` and friends) after calling [connect] again
  /// following a [disconnect].
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
    // Note: the event stream controllers are deliberately NOT closed
    // here, so a caller's existing .listen() subscriptions remain
    // valid if they call connect() again later.
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

    // Two genuinely different kinds of message arrive on the same
    // socket: request responses (identified by "id", per the
    // standard response format) and subscription push events
    // (identified by "type", per the subscribe method's stream
    // documentation - they never carry an "id"). Route each to the
    // right place instead of assuming every message is a response.
    final id = decoded['id'];
    if (id is int) {
      final completer = _pendingRequests.remove(id);
      completer?.complete(decoded);
      return;
    }

    final type = decoded['type'];
    if (type is String) {
      _routeEvent(type, decoded);
    }
    // Anything with neither a matching "id" nor a recognized "type"
    // is silently ignored, the same way an unmatched "id" already was.
  }

  /// Routes an incoming subscription event to the stream matching its
  /// [type], per the field-to-stream mapping documented at
  /// https://xrpl.org/docs/references/http-websocket-apis/public-api-methods/subscription-methods/subscribe
  ///
  /// Event types this SDK does not yet expose a dedicated stream for
  /// are intentionally ignored rather than raising an error, since
  /// receiving a recognized-but-unhandled event isn't itself a
  /// failure - just a feature not built yet. Each ignored type and
  /// its official documentation:
  /// - `consensusPhase` (from the `consensus` stream): sent when the
  ///   consensus process changes phase. See the "Consensus Stream"
  ///   section of the `subscribe` reference above.
  /// - `bookChanges` (from the `book_changes` stream): sent whenever
  ///   a new ledger is validated, summarizing order book changes -
  ///   relevant to Phase 5 (DEX & Cross-Currency), not this
  ///   sub-version. See the "Book Changes Stream" section of the
  ///   `subscribe` reference above.
  /// - `peerStatusChange` (from the admin-only `peer_status` stream):
  ///   information about connected peer `xrpld` servers, not
  ///   applicable to a client SDK. See the "Peer Status Stream"
  ///   section of the `subscribe` reference above.
  /// - `manifestReceived` (from the `manifests` stream): sent when
  ///   the server receives an update to a validator's ephemeral
  ///   signing key. See the `streams` parameter table in the
  ///   `subscribe` reference above.
  void _routeEvent(String type, Map<String, dynamic> event) {
    switch (type) {
      case 'ledgerClosed':
        _ledgerEventsController.add(event);
      case 'transaction':
        _transactionEventsController.add(event);
      case 'validationReceived':
        _validationEventsController.add(event);
      case 'serverStatus':
        _serverEventsController.add(event);
      default:
      // consensusPhase, bookChanges, peerStatusChange,
      // manifestReceived - see doc comment above for why each is
      // intentionally not handled yet.
    }
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
