import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_fee_strategy.dart';

void main() {
  group('XrplFeeStrategy', () {
    test('has exactly the 4 values the fee command reports', () {
      expect(XrplFeeStrategy.values, [
        XrplFeeStrategy.openLedger,
        XrplFeeStrategy.minimum,
        XrplFeeStrategy.median,
        XrplFeeStrategy.base,
      ]);
    });
  });
}
