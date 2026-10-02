import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/transactions/values/xrpl_path_step.dart';

void main() {
  group('XrplPathStep', () {
    test('constructs an account-only step', () {
      final step = XrplPathStep(account: 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe');

      expect(step.account, 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe');
      expect(step.currency, isNull);
      expect(step.issuer, isNull);
    });

    test('constructs a currency-only step', () {
      final step = XrplPathStep(currency: 'USD');

      expect(step.account, isNull);
      expect(step.currency, 'USD');
      expect(step.issuer, isNull);
    });

    test('constructs a currency + issuer step', () {
      final step = XrplPathStep(
        currency: 'USD',
        issuer: 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
      );

      expect(step.currency, 'USD');
      expect(step.issuer, 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B');
    });

    test('constructs an issuer-only step', () {
      final step = XrplPathStep(issuer: 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B');

      expect(step.account, isNull);
      expect(step.currency, isNull);
      expect(step.issuer, 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B');
    });

    test('constructs a step with none of the fields set', () {
      final step = XrplPathStep();

      expect(step.account, isNull);
      expect(step.currency, isNull);
      expect(step.issuer, isNull);
    });

    test('throws ArgumentError when account is combined with currency', () {
      expect(
        () => XrplPathStep(account: 'rAccount', currency: 'USD'),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when account is combined with issuer', () {
      expect(
        () => XrplPathStep(account: 'rAccount', issuer: 'rIssuer'),
        throwsArgumentError,
      );
    });

    test(
      'throws ArgumentError when account is combined with both currency '
      'and issuer',
      () {
        expect(
          () => XrplPathStep(
            account: 'rAccount',
            currency: 'USD',
            issuer: 'rIssuer',
          ),
          throwsArgumentError,
        );
      },
    );

    test('copyWith replaces only the given fields', () {
      final step = XrplPathStep(currency: 'USD', issuer: 'rIssuerOne');

      final updated = step.copyWith(issuer: 'rIssuerTwo');

      expect(updated.currency, 'USD');
      expect(updated.issuer, 'rIssuerTwo');
    });

    test('copyWith still enforces the account exclusion rule', () {
      final step = XrplPathStep(currency: 'USD');

      expect(
        () => step.copyWith(account: 'rAccount'),
        throwsArgumentError,
      );
    });

    test('toJson omits unset fields', () {
      final step = XrplPathStep(currency: 'USD');

      expect(step.toJson(), {'currency': 'USD'});
    });

    test('toJson includes all fields when all are set', () {
      final step = XrplPathStep(
        currency: 'USD',
        issuer: 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
      );

      expect(step.toJson(), {
        'currency': 'USD',
        'issuer': 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
      });
    });

    test('two steps with the same fields are equal', () {
      final a = XrplPathStep(currency: 'USD', issuer: 'rIssuer');
      final b = XrplPathStep(currency: 'USD', issuer: 'rIssuer');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two steps with different fields are not equal', () {
      final a = XrplPathStep(currency: 'USD');
      final b = XrplPathStep(currency: 'EUR');

      expect(a, isNot(equals(b)));
    });
  });

  group('XrplPath', () {
    test('wraps an ordered list of steps', () {
      final step1 = XrplPathStep(account: 'rAccount');
      final step2 = XrplPathStep(currency: 'USD', issuer: 'rIssuer');

      final path = XrplPath([step1, step2]);

      expect(path.steps, [step1, step2]);
    });

    test('toJson converts every step in order', () {
      final path = XrplPath([
        XrplPathStep(account: 'rAccount'),
        XrplPathStep(currency: 'USD', issuer: 'rIssuer'),
      ]);

      expect(path.toJson(), [
        {'account': 'rAccount'},
        {'currency': 'USD', 'issuer': 'rIssuer'},
      ]);
    });

    test('two paths with equal steps in the same order are equal', () {
      final a = XrplPath([XrplPathStep(currency: 'USD')]);
      final b = XrplPath([XrplPathStep(currency: 'USD')]);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two paths with the same steps in a different order are not equal',
        () {
      final a = XrplPath([
        XrplPathStep(currency: 'USD'),
        XrplPathStep(account: 'rAccount'),
      ]);
      final b = XrplPath([
        XrplPathStep(account: 'rAccount'),
        XrplPathStep(currency: 'USD'),
      ]);

      expect(a, isNot(equals(b)));
    });

    test('two paths with a different number of steps are not equal', () {
      final a = XrplPath([XrplPathStep(currency: 'USD')]);
      final b = XrplPath([
        XrplPathStep(currency: 'USD'),
        XrplPathStep(account: 'rAccount'),
      ]);

      expect(a, isNot(equals(b)));
    });
  });
}
