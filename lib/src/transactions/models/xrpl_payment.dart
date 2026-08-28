import 'package:xrpl_flutter_sdk/src/transactions/xrpl_transaction.dart';

/// A `Payment` transaction: sends XRP from one account to another.
///
/// Why this exists: a transaction is fundamentally a plain data
/// structure the network understands, but working with a raw
/// `Map<String, dynamic>` by hand is error-prone (easy to misspell a
/// field name like `"Destintaion"`, or forget the required
/// `TransactionType`). This class gives the required and optional
/// `Payment` fields real, checked Dart types, and [toJson] produces
/// exactly the map the rest of this SDK (and the network) expects.
///
/// Scope for this sub-version: XRP-only. [amountDrops] is always a
/// plain string of drops (the smallest unit of XRP; 1 XRP = 1,000,000
/// drops), not an issued-currency amount object. Payments in other
/// currencies involve XRPL's cross-currency path-finding, which is
/// Phase 5 (DEX & Cross-Currency) - out of scope here.
///
/// This only represents the transaction's *content* - it is not yet
/// signed or submitted. See `autofill` for filling in [sequence],
/// [fee], and [lastLedgerSequence] automatically.
///
/// Example:
/// ```dart
/// final payment = XrplPayment(
///   account: wallet.classicAddress,
///   destination: 'rSomeRecipientAddress...',
///   amountDrops: '10000000', // 10 XRP
/// );
/// ```
///
/// See:
/// https://xrpl.org/docs/references/protocol/transactions/types/payment
class XrplPayment implements XrplTransaction {
  /// Creates a `Payment` transaction. [account], [destination], and
  /// [amountDrops] are required per the official specification;
  /// everything else is optional and typically filled in later by
  /// `autofill`.
  const XrplPayment({
    required this.account,
    required this.destination,
    required this.amountDrops,
    this.destinationTag,
    this.sequence,
    this.fee,
    this.lastLedgerSequence,
    this.flags,
  });

  /// The sending account's classic address.
  @override
  final String account;

  /// The recipient account's classic address.
  final String destination;

  /// The amount to send, in drops (1 XRP = 1,000,000 drops), as a
  /// decimal string - XRPL represents XRP amounts as strings, not
  /// numbers, to avoid floating-point precision issues.
  final String amountDrops;

  /// An optional tag identifying a specific destination sub-account
  /// (for example, a specific customer at an exchange that shares one
  /// XRPL account across many users).
  final int? destinationTag;

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

  /// Transaction-level bit flags. Rarely needed for a simple Payment.
  final int? flags;

  /// Returns a copy of this transaction with the given fields
  /// replaced - used by `autofill` to fill in [sequence], [fee], and
  /// [lastLedgerSequence] without mutating the original.
  @override
  XrplPayment copyWith({
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  }) {
    return XrplPayment(
      account: account,
      destination: destination,
      amountDrops: amountDrops,
      destinationTag: destinationTag,
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
      'TransactionType': 'Payment',
      'Account': account,
      'Destination': destination,
      'Amount': amountDrops,
      if (destinationTag != null) 'DestinationTag': destinationTag,
      if (sequence != null) 'Sequence': sequence,
      if (fee != null) 'Fee': fee,
      if (lastLedgerSequence != null) 'LastLedgerSequence': lastLedgerSequence,
      if (flags != null) 'Flags': flags,
    };
  }
}
