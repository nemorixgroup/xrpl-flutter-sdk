// Phase 1 - 0.0.2-dev: XRPL base58 codec.
//
// Full technical decisions:
// https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-1/base58-codec

import 'dart:typed_data';

import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

/// XRPL encodes seeds and addresses using its own base58 alphabet
/// (different from Bitcoin's), optionally with a checksum to detect
/// typos or corruption.
void base58CodecExample() {
  final data = Uint8List.fromList([0x21, 1, 2, 3, 4, 5]);

  final rawEncoded = XrplBase58.encodeRaw(data);
  print('Raw (no checksum): $rawEncoded');
  print('Raw round-trip matches: '
      '${_bytesEqual(XrplBase58.decodeRaw(rawEncoded), data)}');

  final checksummedEncoded = XrplBase58.encodeWithChecksum(data);
  print('With checksum: $checksummedEncoded');
  print('Checksummed round-trip matches: '
      '${_bytesEqual(XrplBase58.decodeWithChecksum(checksummedEncoded), data)}');

  // A single mistyped character is caught, not silently accepted.
  final lastChar = checksummedEncoded[checksummedEncoded.length - 1];
  final replacement =
      XrplBase58.alphabet.split('').firstWhere((c) => c != lastChar);
  final withTypo =
      '${checksummedEncoded.substring(0, checksummedEncoded.length - 1)}'
      '$replacement';
  try {
    XrplBase58.decodeWithChecksum(withTypo);
  } on XrplCryptoException catch (e) {
    print('Expected validation error: ${e.message}');
  }
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
