/// A single field's binary serialization properties: its type code,
/// field code (`nth`), the exact bytes of its Field ID, and whether
/// it needs a length prefix before its contents.
///
/// Why this exists: these values never change for a field that
/// already exists (see [XrplFieldDefinitions] for why), so there is
/// no reason to compute them at runtime, or to fetch them from a
/// server every time a transaction is signed. They are fixed
/// constants, generated once from a live server's `server_definitions`
/// response by `scripts/regenerate_field_definitions.dart`, and
/// independently cross-checked against official documentation and a
/// third-party implementation's test suite before being committed
/// here.
///
/// [typeCode] and [fieldCode] are stored explicitly, not only derived
/// from [fieldIdBytes], because canonical field ordering sorts by
/// `(typeCode, fieldCode)` as separate numbers - comparing the
/// already-encoded [fieldIdBytes] directly does not reliably produce
/// the same order once fields with different Field ID byte-lengths
/// are mixed together (confirmed against the official worked example,
/// where `Expiration`, a 1-byte Field ID, correctly sorts before
/// `OfferSequence`, a 2-byte Field ID, because `10 < 25` as field
/// codes - a comparison the encoded bytes alone do not preserve).
class XrplFieldDefinition {
  /// Creates a field definition with its exact [typeCode],
  /// [fieldCode], [fieldIdBytes], and [isVLEncoded] flag.
  const XrplFieldDefinition({
    required this.typeCode,
    required this.fieldCode,
    required this.fieldIdBytes,
    required this.isVLEncoded,
  });

  /// The field's type code (for example `2` for `UInt32`, `6` for
  /// `Amount`) - the primary key for canonical field ordering.
  final int typeCode;

  /// The field's field code, also called `nth` in the official
  /// specification - the secondary key for canonical field ordering
  /// (fields of the same [typeCode] are ordered by this).
  final int fieldCode;

  /// The exact bytes that prefix this field in the serialized binary
  /// format (1 to 3 bytes, depending on [typeCode] and [fieldCode]) -
  /// see
  /// https://xrpl.org/docs/references/protocol/binary-format#field-ids.
  final List<int> fieldIdBytes;

  /// Whether this field's contents must be preceded by a length
  /// prefix (1 to 3 additional bytes indicating how many bytes of
  /// content follow) - see
  /// https://xrpl.org/docs/references/protocol/binary-format#length-prefixing.
  final bool isVLEncoded;
}

/// The binary serialization definitions for every field this SDK
/// currently needs, to build `XrplPayment` and `XrplTrustSet`
/// transactions in their canonical binary format for signing.
///
/// These values are permanent, not configuration: a Field ID is part
/// of how a transaction's signing hash is calculated, so changing one
/// for a field that already exists would invalidate every historical
/// transaction and signature on the XRP Ledger - see
/// `docs-sdk/phase-4/binary-serialization/` for the full reasoning.
/// Adding fields for transaction types this SDK doesn't support yet
/// (Phase 5 onward) is normal and expected; re-run
/// `scripts/regenerate_field_definitions.dart` and extend this class
/// when that happens.
///
/// Generated from a live `server_definitions` response against the
/// public Testnet server. Do not hand-edit these values - re-run the
/// generation script instead, so any change goes through the same
/// verification (comparing against known-good values) rather than
/// being transcribed by hand.
class XrplFieldDefinitions {
  const XrplFieldDefinitions._();

  /// Binary definition for the `TransactionType` field.
  static const transactionType = XrplFieldDefinition(
    typeCode: 1,
    fieldCode: 2,
    fieldIdBytes: [0x12],
    isVLEncoded: false,
  );

  /// Binary definition for the `Flags` field.
  static const flags = XrplFieldDefinition(
    typeCode: 2,
    fieldCode: 2,
    fieldIdBytes: [0x22],
    isVLEncoded: false,
  );

  /// Binary definition for the `Sequence` field.
  static const sequence = XrplFieldDefinition(
    typeCode: 2,
    fieldCode: 4,
    fieldIdBytes: [0x24],
    isVLEncoded: false,
  );

  /// Binary definition for the `DestinationTag` field.
  static const destinationTag = XrplFieldDefinition(
    typeCode: 2,
    fieldCode: 14,
    fieldIdBytes: [0x2E],
    isVLEncoded: false,
  );

  /// Binary definition for the `LastLedgerSequence` field.
  static const lastLedgerSequence = XrplFieldDefinition(
    typeCode: 2,
    fieldCode: 27,
    fieldIdBytes: [0x20, 0x1B],
    isVLEncoded: false,
  );

  /// Binary definition for the `SigningPubKey` field.
  static const signingPubKey = XrplFieldDefinition(
    typeCode: 7,
    fieldCode: 3,
    fieldIdBytes: [0x73],
    isVLEncoded: true,
  );

  /// Binary definition for the `TxnSignature` field.
  static const txnSignature = XrplFieldDefinition(
    typeCode: 7,
    fieldCode: 4,
    fieldIdBytes: [0x74],
    isVLEncoded: true,
  );

  /// Binary definition for the `Fee` field.
  static const fee = XrplFieldDefinition(
    typeCode: 6,
    fieldCode: 8,
    fieldIdBytes: [0x68],
    isVLEncoded: false,
  );

  /// Binary definition for the `Amount` field.
  static const amount = XrplFieldDefinition(
    typeCode: 6,
    fieldCode: 1,
    fieldIdBytes: [0x61],
    isVLEncoded: false,
  );

  /// Binary definition for the `Account` field.
  static const account = XrplFieldDefinition(
    typeCode: 8,
    fieldCode: 1,
    fieldIdBytes: [0x81],
    isVLEncoded: true,
  );

  /// Binary definition for the `Destination` field.
  static const destination = XrplFieldDefinition(
    typeCode: 8,
    fieldCode: 3,
    fieldIdBytes: [0x83],
    isVLEncoded: true,
  );

  /// Binary definition for the `LimitAmount` field.
  static const limitAmount = XrplFieldDefinition(
    typeCode: 6,
    fieldCode: 3,
    fieldIdBytes: [0x63],
    isVLEncoded: false,
  );
}

/// The numeric `TransactionType` values for the transaction types this
/// SDK supports, per the official `TRANSACTION_TYPES` map. In binary
/// format, `TransactionType` is serialized as a UInt16 using these
/// numbers, not the string name used in JSON.
class XrplTransactionTypeCode {
  const XrplTransactionTypeCode._();

  /// The numeric `TransactionType` value for a `Payment` transaction.
  static const payment = 0;

  /// The numeric `TransactionType` value for a `TrustSet` transaction.
  static const trustSet = 20;
}
