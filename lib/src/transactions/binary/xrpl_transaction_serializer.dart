import 'dart:typed_data';

import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';
import 'package:xrpl_flutter_sdk/src/transactions/binary/xrpl_amount_serializer.dart';
import 'package:xrpl_flutter_sdk/src/transactions/binary/xrpl_binary_primitives.dart';
import 'package:xrpl_flutter_sdk/src/transactions/binary/xrpl_field_definitions.dart';

/// Serializes a transaction (as the `Map<String, dynamic>` shape
/// `toJson()` produces) into XRPL's canonical binary format.
///
/// Why this works on a plain map, not directly on `XrplPayment` or
/// `XrplTrustSet`: signing a transaction requires serializing it
/// *with* a `SigningPubKey` field but *without* `TxnSignature` (which
/// doesn't exist yet - it's the value being computed), and the final
/// signed transaction needs both. Rather than adding
/// `signingPubKey`/`txnSignature` fields to every transaction model
/// class, the signing process (a later step) adds these keys to the
/// map it already has from `toJson()`, and this serializer stays
/// generic - it only needs to recognize field *names*, not which
/// transaction type they came from.
///
/// Fields are encoded in canonical order: sorted by `(typeCode,
/// fieldCode)`, not by the byte value of their already-encoded Field
/// ID - confirmed against the official worked example, where
/// comparing encoded bytes directly would have sorted `Expiration`
/// and `OfferSequence` incorrectly relative to each other (see
/// `docs-sdk/phase-4/binary-serialization/` for the full case).
///
/// See: https://xrpl.org/docs/references/protocol/binary-format
class XrplTransactionSerializer {
  const XrplTransactionSerializer._();

  /// Serializes [json] into its canonical binary form. Only fields
  /// actually present in [json] are included - this mirrors how
  /// `toJson()` already omits unset optional fields.
  ///
  /// Throws an [XrplCryptoException] if [json] contains a field this
  /// SDK doesn't yet know how to serialize (support is limited to
  /// what `XrplPayment` and `XrplTrustSet` currently need), or if any
  /// field's value fails its own encoder's validation (for example,
  /// an invalid address or amount).
  static Uint8List serialize(Map<String, dynamic> json) {
    final entries = <_FieldEntry>[];

    void addIfPresent(
      String key,
      XrplFieldDefinition definition,
      Uint8List Function(dynamic value) encode,
    ) {
      if (json.containsKey(key)) {
        entries.add(_FieldEntry(definition, encode(json[key])));
      }
    }

    addIfPresent(
      'TransactionType',
      XrplFieldDefinitions.transactionType,
      (v) => XrplBinaryPrimitives.encodeUInt16(
        _transactionTypeCode(v as String),
      ),
    );
    addIfPresent(
      'Flags',
      XrplFieldDefinitions.flags,
      (v) => XrplBinaryPrimitives.encodeUInt32(v as int),
    );
    addIfPresent(
      'Sequence',
      XrplFieldDefinitions.sequence,
      (v) => XrplBinaryPrimitives.encodeUInt32(v as int),
    );
    addIfPresent(
      'DestinationTag',
      XrplFieldDefinitions.destinationTag,
      (v) => XrplBinaryPrimitives.encodeUInt32(v as int),
    );
    addIfPresent(
      'LastLedgerSequence',
      XrplFieldDefinitions.lastLedgerSequence,
      (v) => XrplBinaryPrimitives.encodeUInt32(v as int),
    );
    addIfPresent(
      'SigningPubKey',
      XrplFieldDefinitions.signingPubKey,
      (v) => XrplBinaryPrimitives.encodeBlob(v as String),
    );
    addIfPresent(
      'TxnSignature',
      XrplFieldDefinitions.txnSignature,
      (v) => XrplBinaryPrimitives.encodeBlob(v as String),
    );
    addIfPresent(
      'Fee',
      XrplFieldDefinitions.fee,
      (v) => XrplAmountSerializer.encodeXrpAmount(v as String),
    );
    addIfPresent(
      'Amount',
      XrplFieldDefinitions.amount,
      // Amount is XRP-only for this SDK's current scope (see
      // XrplPayment's own scope note) - always a plain drops string,
      // never an issued-currency object, for this field specifically.
      (v) => XrplAmountSerializer.encodeXrpAmount(v as String),
    );
    addIfPresent(
      'Account',
      XrplFieldDefinitions.account,
      (v) => XrplBinaryPrimitives.encodeAccountId(v as String),
    );
    addIfPresent(
      'Destination',
      XrplFieldDefinitions.destination,
      (v) => XrplBinaryPrimitives.encodeAccountId(v as String),
    );
    addIfPresent(
      'LimitAmount',
      XrplFieldDefinitions.limitAmount,
      (v) => _encodeIssuedCurrencyFromMap(v as Map<String, dynamic>),
    );

    final unknownKeys = json.keys.toSet().difference({
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
    });
    if (unknownKeys.isNotEmpty) {
      throw XrplCryptoException(
        'Cannot serialize unsupported field(s): ${unknownKeys.join(', ')}',
      );
    }

    // Canonical order: sort by (typeCode, fieldCode) as separate
    // numbers, not by comparing already-encoded Field ID bytes - see
    // the class-level doc comment for why that distinction matters.
    entries.sort((a, b) {
      final byType = a.definition.typeCode.compareTo(b.definition.typeCode);
      if (byType != 0) return byType;
      return a.definition.fieldCode.compareTo(b.definition.fieldCode);
    });

    final result = <int>[];
    for (final entry in entries) {
      result
        ..addAll(entry.definition.fieldIdBytes)
        ..addAll(entry.encodedValue);
    }
    return Uint8List.fromList(result);
  }

  static int _transactionTypeCode(String name) {
    switch (name) {
      case 'Payment':
        return XrplTransactionTypeCode.payment;
      case 'TrustSet':
        return XrplTransactionTypeCode.trustSet;
      default:
        throw XrplCryptoException('Unsupported TransactionType "$name"');
    }
  }

  static Uint8List _encodeIssuedCurrencyFromMap(Map<String, dynamic> map) {
    return XrplAmountSerializer.encodeIssuedCurrencyAmount(
      currency: map['currency'] as String,
      issuer: map['issuer'] as String,
      value: map['value'] as String,
    );
  }
}

class _FieldEntry {
  _FieldEntry(this.definition, this.encodedValue);

  final XrplFieldDefinition definition;
  final Uint8List encodedValue;
}
