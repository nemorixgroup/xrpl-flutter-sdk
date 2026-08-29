import 'package:xrpl_flutter_sdk/src/transactions/xrpl_transaction.dart';

/// A `TrustSet` transaction: creates or modifies a trust line,
/// allowing this account to hold a token issued by another account.
///
/// Why this exists: same reasoning as `XrplPayment` - real Dart
/// types and [toJson] instead of building a raw map by hand.
///
/// This only represents the transaction's *content* - it is not yet
/// signed or submitted. See `autofill` for filling in [sequence],
/// [fee], and [lastLedgerSequence] automatically.
///
/// Example:
/// ```dart
/// final trustSet = XrplTrustSet(
///   account: wallet.classicAddress,
///   currency: 'USD',
///   issuer: 'rTheIssuerAddress...',
///   limitValue: '1000',
/// );
/// ```
///
/// See:
/// https://xrpl.org/docs/references/protocol/transactions/types/trustset
class XrplTrustSet implements XrplTransaction {
  /// Creates a `TrustSet` transaction. [account], [currency],
  /// [issuer], and [limitValue] are required to build the
  /// `LimitAmount` field per the official specification; everything
  /// else is optional and typically filled in later by `autofill`.
  const XrplTrustSet({
    required this.account,
    required this.currency,
    required this.issuer,
    required this.limitValue,
    this.sequence,
    this.fee,
    this.lastLedgerSequence,
    this.flags,
  });

  /// The account extending trust (the one that will be able to hold
  /// the token).
  @override
  final String account;

  /// The three-letter currency code (for example `"USD"`), or a
  /// 40-character hex currency code for non-standard currencies.
  final String currency;

  /// The account that issues the currency being trusted.
  final String issuer;

  /// The maximum amount of the currency this account is willing to
  /// hold, as a decimal string. Unlike `XrplPayment.amountDrops`,
  /// this is never in drops - it's in the issued currency's own
  /// units (for example, `"1000"` means 1000 USD, not 1000 drops).
  final String limitValue;

  /// The sending account's next sequence number. Usually left `null`
  /// and filled in by `autofill`.
  @override
  final int? sequence;

  /// The transaction cost, in drops, as a decimal string. Usually
  /// left `null` and filled in by `autofill`.
  @override
  final String? fee;

  /// The last ledger index this transaction is valid in. Usually left
  /// `null` and filled in by `autofill`.
  @override
  final int? lastLedgerSequence;

  /// Transaction-level bit flags (for example `tfSetNoRipple`,
  /// `tfSetFreeze`). Not validated by this SDK; passed through as-is.
  final int? flags;

  /// Returns a copy of this transaction with the given fields
  /// replaced - used by `autofill` to fill in [sequence], [fee], and
  /// [lastLedgerSequence] without mutating the original.
  @override
  XrplTrustSet copyWith({
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  }) {
    return XrplTrustSet(
      account: account,
      currency: currency,
      issuer: issuer,
      limitValue: limitValue,
      sequence: sequence ?? this.sequence,
      fee: fee ?? this.fee,
      lastLedgerSequence: lastLedgerSequence ?? this.lastLedgerSequence,
      flags: flags,
    );
  }

  /// Converts this transaction into the JSON shape XRPL expects,
  /// including the required `TransactionType` field and the nested
  /// `LimitAmount` object. Optional fields left `null` are omitted
  /// entirely, not sent as `null`.
  @override
  Map<String, dynamic> toJson() {
    return {
      'TransactionType': 'TrustSet',
      'Account': account,
      'LimitAmount': {
        'currency': currency,
        'issuer': issuer,
        'value': limitValue,
      },
      if (sequence != null) 'Sequence': sequence,
      if (fee != null) 'Fee': fee,
      if (lastLedgerSequence != null) 'LastLedgerSequence': lastLedgerSequence,
      if (flags != null) 'Flags': flags,
    };
  }
}
