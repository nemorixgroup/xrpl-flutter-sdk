import 'package:xrpl_flutter_sdk/src/transactions/xrpl_transaction.dart';

/// An `OfferCancel` transaction: removes an Offer from XRPL's
/// decentralized exchange.
///
/// Why this exists: same reasoning as `XrplPayment` - real Dart types
/// and [toJson] instead of building a raw map by hand.
///
/// This always reports `tesSUCCESS`, even if [offerSequence] doesn't
/// match any Offer currently in the ledger - confirming whether
/// anything was actually removed requires inspecting the
/// transaction's metadata for a `DeletedNode` of type `Offer`, not
/// just the top-level result code.
///
/// This only represents the transaction's *content* - it is not yet
/// signed or submitted. See `autofill` for filling in `sequence`,
/// `fee`, and `lastLedgerSequence` automatically.
///
/// Example:
/// ```dart
/// final cancel = XrplOfferCancel(
///   account: wallet.classicAddress,
///   offerSequence: 6,
/// );
/// ```
///
/// See:
/// https://xrpl.org/docs/references/protocol/transactions/types/offercancel
class XrplOfferCancel implements XrplTransaction {
  /// Creates an `OfferCancel` transaction. [account] and
  /// [offerSequence] are both required per the official specification.
  const XrplOfferCancel({
    required this.account,
    required this.offerSequence,
    this.sequence,
    this.fee,
    this.lastLedgerSequence,
  });

  /// The account that owns the Offer being canceled.
  @override
  final String account;

  /// The sequence number (or Ticket number) of the `OfferCreate`
  /// transaction that placed the Offer to cancel. Not an error if no
  /// matching Offer exists.
  final int offerSequence;

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

  /// Returns a copy of this transaction with the given fields
  /// replaced - used by `autofill` to fill in [sequence], [fee], and
  /// [lastLedgerSequence] without mutating the original.
  @override
  XrplOfferCancel copyWith({
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  }) {
    return XrplOfferCancel(
      account: account,
      offerSequence: offerSequence,
      sequence: sequence ?? this.sequence,
      fee: fee ?? this.fee,
      lastLedgerSequence: lastLedgerSequence ?? this.lastLedgerSequence,
    );
  }

  /// Converts this transaction into the JSON shape XRPL expects,
  /// including the required `TransactionType` field. Optional fields
  /// left `null` are omitted entirely, not sent as `null`.
  @override
  Map<String, dynamic> toJson() {
    return {
      'TransactionType': 'OfferCancel',
      'Account': account,
      'OfferSequence': offerSequence,
      if (sequence != null) 'Sequence': sequence,
      if (fee != null) 'Fee': fee,
      if (lastLedgerSequence != null) 'LastLedgerSequence': lastLedgerSequence,
    };
  }
}
