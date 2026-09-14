import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/src/codec/xrpl_hex_codec.dart';

void main() {
  group('XrplHexCodec.bytesToHex', () {
    test('converts bytes to uppercase hex', () {
      final bytes = Uint8List.fromList([0x0a, 0xff, 0x00, 0x21]);
      expect(XrplHexCodec.bytesToHex(bytes), '0AFF0021');
    });

    test('pads single-digit bytes with a leading zero', () {
      final bytes = Uint8List.fromList([0x01, 0x02]);
      expect(XrplHexCodec.bytesToHex(bytes), '0102');
    });

    test('returns an empty string for empty input', () {
      expect(XrplHexCodec.bytesToHex(<int>[]), '');
    });
  });

  group('XrplHexCodec.hexToBytes', () {
    test('converts an uppercase hex string back to bytes', () {
      expect(
        XrplHexCodec.hexToBytes('0AFF0021'),
        Uint8List.fromList([0x0a, 0xff, 0x00, 0x21]),
      );
    });

    test('is case-insensitive', () {
      expect(
        XrplHexCodec.hexToBytes('0aff0021'),
        XrplHexCodec.hexToBytes('0AFF0021'),
      );
    });
  });

  group('XrplHexCodec round-trip', () {
    test('bytesToHex then hexToBytes returns the original bytes', () {
      final original = Uint8List.fromList([0x12, 0x34, 0xab, 0xcd, 0x00]);
      final roundTripped = XrplHexCodec.hexToBytes(
        XrplHexCodec.bytesToHex(original),
      );
      expect(roundTripped, original);
    });
  });
}
