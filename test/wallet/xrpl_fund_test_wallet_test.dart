import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_endpoint.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_connection_exception.dart';
import 'package:xrpl_flutter_sdk/src/wallet/xrpl_fund_test_wallet.dart';

void main() {
  group('fundTestWallet mainnet rejection', () {
    test(
        'throws immediately for XrplEndpoint.mainnet, without '
        'attempting any network request', () async {
      await expectLater(
        fundTestWallet(XrplEndpoint.mainnet),
        throwsA(isA<XrplConnectionException>()),
      );
    });
  });
}
