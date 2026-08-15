import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_connection_exception.dart';

void main() {
  group('XrplConnectionException', () {
    test('stores the provided message', () {
      const exception = XrplConnectionException('Server unreachable');
      expect(exception.message, 'Server unreachable');
    });

    test('toString includes the type name and message', () {
      const exception = XrplConnectionException('Request timed out');
      expect(
        exception.toString(),
        'XrplConnectionException: Request timed out',
      );
    });

    test('implements Exception, so it can be caught as one', () {
      expect(
        () => throw const XrplConnectionException('boom'),
        throwsA(isA<Exception>()),
      );
    });

    test('is a distinct type from a generic Exception', () {
      const exception = XrplConnectionException('distinct type check');
      expect(exception, isA<XrplConnectionException>());
    });
  });
}
