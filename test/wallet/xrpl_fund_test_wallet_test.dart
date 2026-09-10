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
}
