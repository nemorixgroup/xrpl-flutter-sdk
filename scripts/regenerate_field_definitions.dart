// Internal maintenance tool - NOT part of the public SDK API.
//
// Regenerates the field definitions this SDK's binary codec (0.3.2-dev)
// relies on, by querying a real XRPL server's `server_definitions`
// command - rather than hand-transcribing values from documentation or
// a JSON file, which is exactly the kind of manual-transcription
// mistake this SDK has caught before (see the Phase 1 Ed25519 prefix
// bug in docs-sdk/).
//
// This is run manually by maintainers, only when adding support for a
// new transaction type or field - never at runtime by the SDK itself
// or by an application using it. Signing a transaction never requires
// network access; the values this script prints are meant to be
// copied into a static Dart file once, reviewed, and committed.
//
// Usage:
//   dart run scripts/regenerate_field_definitions.dart
// ignore_for_file: avoid_print

import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

// Every field this SDK currently needs to serialize Payment and
// TrustSet transactions (plus their shared signing fields). Extend
// this list when adding support for a new transaction type.
const _neededFields = [
  'TransactionType',
  'Flags',
  'Sequence',
  'DestinationTag',
  'LastLedgerSequence',
  'SigningPubKey',
  'TxnSignature',
  'Fee',
  'Amount',
  'Account',
  'Destination',
  'LimitAmount',
];

// Independently confirmed earlier via official documentation and a
// cross-checked third-party implementation's test suite - used here
// purely as a sanity check against the live server response, not as
// the source of truth.
const _knownGoodFieldIdBytes = {
  'TransactionType': [0x12],
  'Flags': [0x22],
  'Sequence': [0x24],
  'Fee': [0x68],
  'SigningPubKey': [0x73],
  'TxnSignature': [0x74],
  'Account': [0x81],
};

void main() async {
  final connection = XrplConnection(XrplEndpoint.testnet);
  await connection.connect();

  final response = await connection.request('server_definitions');
  final result = response['result'] as Map<String, dynamic>;

  final types = result['TYPES'] as Map<String, dynamic>;
  final fields = result['FIELDS'] as List<dynamic>;
  final transactionTypes = result['TRANSACTION_TYPES'] as Map<String, dynamic>;

  print('// Generated from a live server_definitions response.');
  print('// TransactionType values needed:');
  print('//   Payment = ${transactionTypes['Payment']}');
  print('//   TrustSet = ${transactionTypes['TrustSet']}');
  print('');

  for (final fieldName in _neededFields) {
    final entry = fields.cast<List<dynamic>>().firstWhere(
          (f) => f[0] == fieldName,
          orElse: () => throw StateError(
            'Field "$fieldName" not found in server_definitions response.',
          ),
        );
    final props = entry[1] as Map<String, dynamic>;
    final typeName = props['type'] as String;
    final nth = props['nth'] as int;
    final isVLEncoded = props['isVLEncoded'] as bool;
    final typeCode = types[typeName] as int;

    final fieldIdBytes = _computeFieldIdBytes(typeCode, nth);
    final bytesHex = fieldIdBytes
        .map((b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}')
        .join(', ');

    final knownGood = _knownGoodFieldIdBytes[fieldName];
    final check = knownGood == null
        ? ''
        : _listsEqual(knownGood, fieldIdBytes)
            ? ' [matches known-good value]'
            : ' [MISMATCH! expected $knownGood]';

    print(
      '$fieldName: type=$typeName ($typeCode), nth=$nth, '
      'isVLEncoded=$isVLEncoded, fieldIdBytes=[$bytesHex]$check',
    );
  }

  await connection.disconnect();
}

/// Computes a Field ID's exact bytes from a type code and field code
/// (nth), per the official rule at
/// xrpl.org/docs/references/protocol/binary-format#field-ids. Returns
/// the bytes directly, rather than a combined integer, since the
/// byte count itself (1, 2, or 3) depends on both codes and would
/// otherwise have to be re-derived by whoever reads the result.
List<int> _computeFieldIdBytes(int typeCode, int fieldCode) {
  if (typeCode < 16 && fieldCode < 16) {
    return [(typeCode << 4) | fieldCode];
  } else if (typeCode < 16 && fieldCode >= 16) {
    return [typeCode << 4, fieldCode];
  } else if (typeCode >= 16 && fieldCode < 16) {
    return [fieldCode, typeCode];
  } else {
    return [0x00, typeCode, fieldCode];
  }
}

bool _listsEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
