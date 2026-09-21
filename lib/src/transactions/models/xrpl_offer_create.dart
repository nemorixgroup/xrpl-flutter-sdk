import 'package:xrpl_flutter_sdk/src/transactions/values/xrpl_currency_amount.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_transaction.dart';

/// An `OfferCreate` transaction: places an Offer in XRPL's
/// decentralized exchange - an intent to trade one currency for
/// another.
///
/// Why this exists: same reasoning as `XrplPayment` - real Dart types
/// and [toJson] instead of building a raw map by hand.
///
/// Unlike `XrplPayment.amountDrops` (deliberately XRP-only in Phase
/// 4), [takerGets] and [takerPays] are never limited to XRP - trading
/// only XRP for XRP would make an Offer meaningless. Both use
/// [XrplCurrencyAmount], which makes "XRP or issued currency"
/// explicit and mutually exclusive at construction.
///
/// When processed, this automatically consumes matching or crossing
/// Offers to the extent possible. Any remainder becomes an `Offer`
/// object in the ledger, waiting for a future match. See
/// [XrplOfferCreateFlags] for the three ways to change this default
/// behavior (`tfPassive`, `tfImmediateOrCancel`, `tfFillOrKill`).
///
/// This only represents the transaction's *content* - it is not yet
/// signed or submitted. See `autofill` for filling in `sequence`,
/// `fee`, and `lastLedgerSequence` automatically.
///
/// Example:
/// ```dart
/// final offer = XrplOfferCreate(
///   account: wallet.classicAddress,
///   takerGets: XrplCurrencyAmount.xrp('6000000'),
///   takerPays: XrplCurrencyAmount.issued(
///     currency: 'GKO',
///     issuer: 'ruazs5h1qEsqpke88pcqnaseXdm6od2xc',
///     value: '2',
///   ),
/// );
/// ```
///
/// See:
/// https://xrpl.org/docs/references/protocol/transactions/types/offercreate
class XrplOfferCreate implements XrplTransaction {
  /// Creates an `OfferCreate` transaction. [account], [takerGets], and
  /// [takerPays] are required per the official specification;
  /// everything else is optional and typically filled in later by
  /// `autofill`.
  const XrplOfferCreate({
    required this.account,
    required this.takerGets,
    required this.takerPays,
    this.expiration,
    this.offerSequence,
    this.sequence,
    this.fee,
    this.lastLedgerSequence,
    this.flags,
  });

  /// The account placing the Offer.
  @override
  final String account;

  /// The amount and type of currency being sold.
  final XrplCurrencyAmount takerGets;

  /// The amount and type of currency being bought.
  final XrplCurrencyAmount takerPays;

  /// Time after which the Offer is no longer active, in seconds since
  /// the Ripple Epoch. Rarely needed for a simple Offer.
  final int? expiration;

  /// An existing Offer to cancel first, specified the same way as
  /// `XrplOfferCancel.offerSequence` - lets one transaction replace
  /// an old Offer with a new one, instead of sending a separate
  /// `OfferCancel` beforehand.
  final int? offerSequence;

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

  /// Transaction-level bit flags - see [XrplOfferCreateFlags] for the
  /// named values this transaction type supports. Not validated by
  /// this SDK; passed through as-is.
  final int? flags;

  /// Returns a copy of this transaction with the given fields
  /// replaced - used by `autofill` to fill in [sequence], [fee], and
  /// [lastLedgerSequence] without mutating the original.
  @override
  XrplOfferCreate copyWith({
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  }) {
    return XrplOfferCreate(
      account: account,
      takerGets: takerGets,
      takerPays: takerPays,
      expiration: expiration,
      offerSequence: offerSequence,
      sequence: sequence ?? this.sequence,
      fee: fee ?? this.fee,
      lastLedgerSequence: lastLedgerSequence ?? this.lastLedgerSequence,
      flags: flags,
    );
  }

  /// Converts this transaction into the JSON shape XRPL expects,
  /// including the required `TransactionType` field. Fields left
  /// `null` are omitted entirely, not sent as `null`.
  @override
  Map<String, dynamic> toJson() {
    return {
      'TransactionType': 'OfferCreate',
      'Account': account,
      'TakerGets': takerGets.toJson(),
      'TakerPays': takerPays.toJson(),
      if (expiration != null) 'Expiration': expiration,
      if (offerSequence != null) 'OfferSequence': offerSequence,
      if (sequence != null) 'Sequence': sequence,
      if (fee != null) 'Fee': fee,
      if (lastLedgerSequence != null) 'LastLedgerSequence': lastLedgerSequence,
      if (flags != null) 'Flags': flags,
    };
  }
}

/// The named `Flags` values `OfferCreate` supports, per the official
/// specification. Combine with bitwise OR (`|`) to use more than one
/// at a time (though `tfImmediateOrCancel` and `tfFillOrKill` are
/// mutually exclusive - the network rejects a transaction using
/// both).
class XrplOfferCreateFlags {
  const XrplOfferCreateFlags._();

  /// Do not consume Offers that exactly match this one - only ones
  /// that cross it. Lets an Offer sit in the ledger pegged at a
  /// specific exchange rate.
  static const tfPassive = 0x00010000;

  /// Trade only as much as can be matched immediately; never place a
  /// remainder into the ledger as an `Offer` object.
  static const tfImmediateOrCancel = 0x00020000;

  /// Either fully match immediately, or do nothing at all; never
  /// place a partial remainder into the ledger.
  static const tfFillOrKill = 0x00040000;
}
