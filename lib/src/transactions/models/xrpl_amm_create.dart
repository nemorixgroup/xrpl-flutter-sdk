import 'package:xrpl_flutter_sdk/src/transactions/values/xrpl_currency_amount.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_owner_reserve_cost_transaction.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_transaction.dart';

/// An `AMMCreate` transaction: creates an Automated Market Maker
/// pool for a pair of assets, funded with an initial deposit of each.
///
/// The two assets of the pool are the ones named by [amount] and
/// [amount2], each of which is either XRP or an issued token (see
/// [XrplCurrencyAmount]). The sender becomes the first liquidity
/// provider and receives LP tokens for 100% of the pool.
///
/// This constructor validates the rules the official documentation
/// states for the transaction itself, and throws an [ArgumentError]
/// when one is broken:
///
/// - [tradingFee] must be between 0 and [maxTradingFee] (1000, which
///   is a 1% fee, in units of 1/100,000).
/// - Both amounts must be positive.
/// - At most one of the two assets can be XRP.
/// - The two assets cannot be the same token (same currency code and
///   same issuer).
///
/// Rules that depend on the state of the ledger, such as whether the
/// pool already exists, whether the issuer enabled Default Ripple, or
/// whether the sender holds enough of each asset, are not checked
/// here. The server rejects those with its own result code (for
/// example `tecDUPLICATE`).
///
/// An `AMMCreate` must destroy at least the network's incremental
/// owner reserve as its transaction cost, not the usual small fee.
/// That is what [XrplOwnerReserveCostTransaction] tells `autofill`:
/// when [fee] is `null`, `autofill` reads the reserve from the
/// network. If you set [fee] yourself, it is used as given.
///
/// This only represents the transaction's *content*: it is not yet
/// signed or submitted.
///
/// Example:
/// ```dart
/// final create = XrplAmmCreate(
///   account: wallet.classicAddress,
///   amount: const XrplCurrencyAmount.xrp('10000000'),
///   amount2: const XrplCurrencyAmount.issued(
///     currency: 'TST',
///     issuer: 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd',
///     value: '25',
///   ),
///   tradingFee: 500, // 0.5%
/// );
/// ```
///
/// See:
/// https://xrpl.org/docs/references/protocol/transactions/types/ammcreate
class XrplAmmCreate
    implements XrplTransaction, XrplOwnerReserveCostTransaction {
  /// Creates an `AMMCreate` transaction. [account], [amount],
  /// [amount2], and [tradingFee] are required per the official
  /// specification; the rest is optional and typically filled in later
  /// by `autofill`.
  ///
  /// Throws an [ArgumentError] if any rule listed in this class's
  /// documentation is broken.
  XrplAmmCreate({
    required this.account,
    required this.amount,
    required this.amount2,
    required this.tradingFee,
    this.sequence,
    this.fee,
    this.lastLedgerSequence,
  }) {
    _validate();
  }

  /// The highest `TradingFee` the network accepts: 1000, which is a 1%
  /// fee.
  static const maxTradingFee = 1000;

  /// The account creating the AMM and funding it.
  @override
  final String account;

  /// The first of the two assets to fund the pool with. Must be
  /// positive.
  final XrplCurrencyAmount amount;

  /// The second of the two assets to fund the pool with. Must be
  /// positive.
  final XrplCurrencyAmount amount2;

  /// The fee charged for trades against this pool, in units of
  /// 1/100,000 (1 equals 0.001%), from 0 to [maxTradingFee].
  final int tradingFee;

  /// The sending account's next sequence number. Usually left `null`
  /// and filled in by `autofill`.
  @override
  final int? sequence;

  /// The transaction cost, in drops, as a decimal string. Usually left
  /// `null` and filled in by `autofill`, which uses the network's
  /// incremental owner reserve for this transaction type.
  @override
  final String? fee;

  /// The last ledger index this transaction is valid in. Usually left
  /// `null` and filled in by `autofill`.
  @override
  final int? lastLedgerSequence;

  /// Returns a copy of this transaction with the given fields
  /// replaced, used by `autofill` to fill in [sequence], [fee], and
  /// [lastLedgerSequence] without mutating the original.
  @override
  XrplAmmCreate copyWith({
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  }) {
    return XrplAmmCreate(
      account: account,
      amount: amount,
      amount2: amount2,
      tradingFee: tradingFee,
      sequence: sequence ?? this.sequence,
      fee: fee ?? this.fee,
      lastLedgerSequence: lastLedgerSequence ?? this.lastLedgerSequence,
    );
  }

  /// Converts this transaction into the JSON shape XRPL expects,
  /// including the required `TransactionType` field. Fields left
  /// `null` are omitted entirely, not sent as `null`.
  @override
  Map<String, dynamic> toJson() {
    return {
      'TransactionType': 'AMMCreate',
      'Account': account,
      'Amount': amount.toJson(),
      'Amount2': amount2.toJson(),
      'TradingFee': tradingFee,
      if (sequence != null) 'Sequence': sequence,
      if (fee != null) 'Fee': fee,
      if (lastLedgerSequence != null) 'LastLedgerSequence': lastLedgerSequence,
    };
  }

  void _validate() {
    if (tradingFee < 0 || tradingFee > maxTradingFee) {
      throw ArgumentError.value(
        tradingFee,
        'tradingFee',
        'must be between 0 and $maxTradingFee',
      );
    }
    _requirePositive(amount, 'amount');
    _requirePositive(amount2, 'amount2');
    if (amount.isXrp && amount2.isXrp) {
      throw ArgumentError(
        'An AMM pool can hold at most one XRP asset, but both amount '
        'and amount2 are XRP.',
      );
    }
    if (!amount.isXrp &&
        !amount2.isXrp &&
        amount.currency == amount2.currency &&
        amount.issuer == amount2.issuer) {
      throw ArgumentError(
        'amount and amount2 must be different assets, but both are '
        '${amount.currency} issued by ${amount.issuer}.',
      );
    }
  }

  static void _requirePositive(XrplCurrencyAmount value, String name) {
    final bool positive;
    if (value.isXrp) {
      final drops = BigInt.tryParse(value.drops!);
      positive = drops != null && drops > BigInt.zero;
    } else {
      final parsed = double.tryParse(value.value!);
      positive = parsed != null && parsed.isFinite && parsed > 0;
    }
    if (!positive) {
      throw ArgumentError.value(
        value.isXrp ? value.drops : value.value,
        name,
        'must be a positive amount',
      );
    }
  }
}
