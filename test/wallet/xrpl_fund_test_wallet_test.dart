import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

void main() {
  group('fundTestWallet mainnet rejection', () {
    test(
        'throws immediately for XrplEndpoint.mainnet, without '
        'attempting any network request', () async {
      final connection = XrplConnection(XrplEndpoint.mainnet);
      await expectLater(
        fundTestWallet(connection),
        throwsA(isA<XrplConnectionException>()),
      );
    });
  });

  group('fundTestWallet maxAttempts/attemptDelay validation', () {
    test(
        'throws immediately for a zero maxAttempts, without '
        'attempting any network request', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await expectLater(
        fundTestWallet(connection, maxAttempts: 0),
        throwsA(isA<XrplConnectionException>()),
      );
    });

    test(
        'throws immediately for a negative maxAttempts, without '
        'attempting any network request', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await expectLater(
        fundTestWallet(connection, maxAttempts: -1),
        throwsA(isA<XrplConnectionException>()),
      );
    });

    test(
        'throws immediately for a zero attemptDelay, without '
        'attempting any network request', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await expectLater(
        fundTestWallet(connection, attemptDelay: Duration.zero),
        throwsA(isA<XrplConnectionException>()),
      );
    });

    test(
        'throws immediately for a negative attemptDelay, without '
        'attempting any network request', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await expectLater(
        fundTestWallet(
          connection,
          attemptDelay: const Duration(seconds: -1),
        ),
        throwsA(isA<XrplConnectionException>()),
      );
    });
  });
}
