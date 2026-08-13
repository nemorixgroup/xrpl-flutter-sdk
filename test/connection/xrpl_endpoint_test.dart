import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_endpoint.dart';

void main() {
  group('XrplEndpoint.websocketUrl', () {
    test('mainnet matches the official public server URL', () {
      expect(
        XrplEndpoint.mainnet.websocketUrl,
        'wss://xrplcluster.com/',
      );
    });

    test('testnet matches the official public server URL', () {
      expect(
        XrplEndpoint.testnet.websocketUrl,
        'wss://s.altnet.rippletest.net:51233/',
      );
    });

    test('devnet matches the official public server URL', () {
      expect(
        XrplEndpoint.devnet.websocketUrl,
        'wss://s.devnet.rippletest.net:51233/',
      );
    });

    test('every endpoint has a distinct URL', () {
      final urls = XrplEndpoint.values.map((e) => e.websocketUrl).toSet();
      expect(urls.length, XrplEndpoint.values.length);
    });

    test('every URL uses the secure WebSocket scheme', () {
      for (final endpoint in XrplEndpoint.values) {
        expect(endpoint.websocketUrl, startsWith('wss://'));
      }
    });
  });
}
