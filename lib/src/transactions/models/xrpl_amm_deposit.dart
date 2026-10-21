import 'package:xrpl_flutter_sdk/src/transactions/values/xrpl_asset.dart';
import 'package:xrpl_flutter_sdk/src/transactions/values/xrpl_currency_amount.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_transaction.dart';

/// An `AMMDeposit` transaction: deposits funds into an existing
/// Automated Market Maker (AMM) pool and receives the pool's
/// liquidity provider (LP) tokens in exchange.
///
/// The pool is identified by [asset] and [asset2]. What is deposited
/// depends on the deposit mode, and the official specification allows
/// exactly six, each with a fixed set of fields. Rather than one
/// constructor with many optional fields (where most combinations are
/// invalid), each mode has its own named constructor, so an invalid
/// combination cannot be written at all:
///
/// | Constructor | Fields | What it does |
/// |---|---|---|
/// | [XrplAmmDeposit.lpToken] | `lpTokenOut` | Deposits both assets in proportion to receive that many LP tokens |
/// | [XrplAmmDeposit.twoAsset] | `amount`, `amount2` | Deposits up to those amounts of both assets |
/// | [XrplAmmDeposit.twoAssetIfEmpty] | `amount`, `amount2` | Deposits exact amounts into an empty pool, setting its ratio |
/// | [XrplAmmDeposit.singleAsset] | `amount` | Deposits one asset |
/// | [XrplAmmDeposit.oneAssetLpToken] | `amount`, `lpTokenOut` | Deposits up to `amount` of one asset to receive exactly `lpTokenOut` |
/// | [XrplAmmDeposit.limitLpToken] | `amount`, `ePrice` | Deposits up to `amount` of one asset, without paying more than `ePrice` per LP token |
///
/// Double-asset deposits have no pool fee. Single-asset deposits do:
/// it is taken from the LP tokens received.
///
/// Unlike `AMMCreate`, this transaction pays the normal transaction
/// cost, so `autofill` needs no special handling for it.
///
/// Only rules that can be checked without ledger state are validated
/// at construction, each throwing an [ArgumentError]:
///
/// - [asset] and [asset2] must be different assets.
/// - Every amount must be positive.
/// - [amount] and [amount2] must each be one of the pool's two assets,
///   and must not be the same asset as each other.
/// - [lpTokenOut] must be an issued currency (LP tokens are never
///   XRP).
///
/// Everything that depends on the ledger is left to the server and
/// surfaces as its result code: `terNO_AMM` (no such pool),
/// `tecAMM_EMPTY`, `tecAMM_NOT_EMPTY`, `tecUNFUNDED_AMM`,
/// `tecAMM_FAILED`, `tecFROZEN`, `tecNO_AUTH`, and others.
///
/// Known limitation: [ePrice] is only checked to be positive. The
/// documentation says it is expressed "in the deposit asset", but this
/// SDK does not enforce that the server-side.
///
/// See:
/// https://xrpl.org/docs/references/protocol/transactions/types/ammdeposit
class XrplAmmDeposit implements XrplTransaction {
  XrplAmmDeposit._({
    required this.account,
    required this.asset,
    required this.asset2,
    required this.flags,
    this.amount,
    this.amount2,
    this.ePrice,
    this.lpTokenOut,
    this.sequence,
    this.fee,
    this.lastLedgerSequence,
  }) {
    _validate();
  }

  /// Deposits both assets in proportion to the pool's current ratio,
  /// to receive exactly [lpTokenOut] LP tokens (`tfLPToken`).
  ///
  /// Throws an [ArgumentError] if any rule listed in this class's
  /// documentation is broken.
  XrplAmmDeposit.lpToken({
    required String account,
    required XrplAsset asset,
    required XrplAsset asset2,
    required XrplCurrencyAmount lpTokenOut,
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  }) : this._(
          account: account,
          asset: asset,
          asset2: asset2,
          flags: tfLpToken,
          lpTokenOut: lpTokenOut,
          sequence: sequence,
          fee: fee,
          lastLedgerSequence: lastLedgerSequence,
        );

  /// Deposits up to [amount] and [amount2] of the two pool assets
  /// (`tfTwoAsset`). Either may end up smaller, to keep the pool's
  /// balance.
  ///
  /// Throws an [ArgumentError] if any rule listed in this class's
  /// documentation is broken.
  XrplAmmDeposit.twoAsset({
    required String account,
    required XrplAsset asset,
    required XrplAsset asset2,
    required XrplCurrencyAmount amount,
    required XrplCurrencyAmount amount2,
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  }) : this._(
          account: account,
          asset: asset,
          asset2: asset2,
          flags: tfTwoAsset,
          amount: amount,
          amount2: amount2,
          sequence: sequence,
          fee: fee,
          lastLedgerSequence: lastLedgerSequence,
        );

  /// Deposits exactly [amount] and [amount2] into an empty pool,
  /// setting its asset ratio and trading fee (`tfTwoAssetIfEmpty`).
  /// The server rejects it with `tecAMM_NOT_EMPTY` if the pool still
  /// holds assets.
  ///
  /// Throws an [ArgumentError] if any rule listed in this class's
  /// documentation is broken.
  XrplAmmDeposit.twoAssetIfEmpty({
    required String account,
    required XrplAsset asset,
    required XrplAsset asset2,
    required XrplCurrencyAmount amount,
    required XrplCurrencyAmount amount2,
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  }) : this._(
          account: account,
          asset: asset,
          asset2: asset2,
          flags: tfTwoAssetIfEmpty,
          amount: amount,
          amount2: amount2,
          sequence: sequence,
          fee: fee,
          lastLedgerSequence: lastLedgerSequence,
        );

  /// Deposits exactly [amount] of one pool asset (`tfSingleAsset`).
  /// The LP tokens received are based on the resulting pool share,
  /// minus the single-asset deposit fee.
  ///
  /// Throws an [ArgumentError] if any rule listed in this class's
  /// documentation is broken.
  XrplAmmDeposit.singleAsset({
    required String account,
    required XrplAsset asset,
    required XrplAsset asset2,
    required XrplCurrencyAmount amount,
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  }) : this._(
          account: account,
          asset: asset,
          asset2: asset2,
          flags: tfSingleAsset,
          amount: amount,
          sequence: sequence,
          fee: fee,
          lastLedgerSequence: lastLedgerSequence,
        );

  /// Deposits up to [amount] of one pool asset to receive exactly
  /// [lpTokenOut] LP tokens, after fees (`tfOneAssetLPToken`).
  ///
  /// Throws an [ArgumentError] if any rule listed in this class's
  /// documentation is broken.
  XrplAmmDeposit.oneAssetLpToken({
    required String account,
    required XrplAsset asset,
    required XrplAsset asset2,
    required XrplCurrencyAmount amount,
    required XrplCurrencyAmount lpTokenOut,
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  }) : this._(
          account: account,
          asset: asset,
          asset2: asset2,
          flags: tfOneAssetLpToken,
          amount: amount,
          lpTokenOut: lpTokenOut,
          sequence: sequence,
          fee: fee,
          lastLedgerSequence: lastLedgerSequence,
        );

  /// Deposits up to [amount] of one pool asset, without paying more
  /// than [ePrice] per LP token received, after fees
  /// (`tfLimitLPToken`).
  ///
  /// Throws an [ArgumentError] if any rule listed in this class's
  /// documentation is broken.
  XrplAmmDeposit.limitLpToken({
    required String account,
    required XrplAsset asset,
    required XrplAsset asset2,
    required XrplCurrencyAmount amount,
    required XrplCurrencyAmount ePrice,
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  }) : this._(
          account: account,
          asset: asset,
          asset2: asset2,
          flags: tfLimitLpToken,
          amount: amount,
          ePrice: ePrice,
          sequence: sequence,
          fee: fee,
          lastLedgerSequence: lastLedgerSequence,
        );

  /// The `Flags` value of the `tfLPToken` mode.
  static const tfLpToken = 0x00010000;

  /// The `Flags` value of the `tfSingleAsset` mode.
  static const tfSingleAsset = 0x00080000;

  /// The `Flags` value of the `tfTwoAsset` mode.
  static const tfTwoAsset = 0x00100000;

  /// The `Flags` value of the `tfOneAssetLPToken` mode.
  static const tfOneAssetLpToken = 0x00200000;

  /// The `Flags` value of the `tfLimitLPToken` mode.
  static const tfLimitLpToken = 0x00400000;

  /// The `Flags` value of the `tfTwoAssetIfEmpty` mode.
  static const tfTwoAssetIfEmpty = 0x00800000;

  /// The account depositing into the pool.
  @override
  final String account;

  /// One of the two assets identifying the pool.
  final XrplAsset asset;

  /// The other asset identifying the pool.
  final XrplAsset asset2;

  /// The `Flags` value for this transaction's deposit mode: exactly
  /// one of [tfLpToken], [tfSingleAsset], [tfTwoAsset],
  /// [tfOneAssetLpToken], [tfLimitLpToken] or [tfTwoAssetIfEmpty].
  final int flags;

  /// The amount of one pool asset to deposit, or `null` in the
  /// [XrplAmmDeposit.lpToken] mode.
  final XrplCurrencyAmount? amount;

  /// The amount of the other pool asset to deposit, only in the
  /// [XrplAmmDeposit.twoAsset] and [XrplAmmDeposit.twoAssetIfEmpty]
  /// modes.
  final XrplCurrencyAmount? amount2;

  /// The maximum effective price to pay per LP token, only in the
  /// [XrplAmmDeposit.limitLpToken] mode.
  final XrplCurrencyAmount? ePrice;

  /// How many LP tokens to buy, only in the [XrplAmmDeposit.lpToken]
  /// and [XrplAmmDeposit.oneAssetLpToken] modes. Its currency is the
  /// pool's LP token code and its issuer is the AMM account (both are
  /// reported by `ammInfo` as `lpToken`).
  final XrplCurrencyAmount? lpTokenOut;

  /// The sending account's next sequence number. Usually left `null`
  /// and filled in by `autofill`.
  @override
  final int? sequence;

  /// The transaction cost, in drops, as a decimal string. Usually left
  /// `null` and filled in by `autofill`.
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
  XrplAmmDeposit copyWith({
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  }) {
    return XrplAmmDeposit._(
      account: account,
      asset: asset,
      asset2: asset2,
      flags: flags,
      amount: amount,
      amount2: amount2,
      ePrice: ePrice,
      lpTokenOut: lpTokenOut,
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
      'TransactionType': 'AMMDeposit',
      'Account': account,
      'Asset': asset.toJson(),
      'Asset2': asset2.toJson(),
      if (amount != null) 'Amount': amount!.toJson(),
      if (amount2 != null) 'Amount2': amount2!.toJson(),
      if (ePrice != null) 'EPrice': ePrice!.toJson(),
      if (lpTokenOut != null) 'LPTokenOut': lpTokenOut!.toJson(),
      'Flags': flags,
      if (sequence != null) 'Sequence': sequence,
      if (fee != null) 'Fee': fee,
      if (lastLedgerSequence != null) 'LastLedgerSequence': lastLedgerSequence,
    };
  }

  void _validate() {
    if (asset == asset2) {
      throw ArgumentError(
        'asset and asset2 must be different assets, but both are '
        '${asset.toJson()}.',
      );
    }

    final firstAmount = amount;
    final secondAmount = amount2;
    final price = ePrice;
    final lpTokens = lpTokenOut;

    if (firstAmount != null) {
      _requirePositive(firstAmount, 'amount');
      _requireInPool(firstAmount, 'amount');
    }
    if (secondAmount != null) {
      _requirePositive(secondAmount, 'amount2');
      _requireInPool(secondAmount, 'amount2');
    }
    if (firstAmount != null &&
        secondAmount != null &&
        _assetOf(firstAmount) == _assetOf(secondAmount)) {
      throw ArgumentError(
        'amount and amount2 must be different assets, but both are '
        '${_assetOf(firstAmount).toJson()}.',
      );
    }
    if (price != null) {
      _requirePositive(price, 'ePrice');
    }
    if (lpTokens != null) {
      if (lpTokens.isXrp) {
        throw ArgumentError.value(
          lpTokens.drops,
          'lpTokenOut',
          'must be an LP token (an issued currency), not XRP',
        );
      }
      _requirePositive(lpTokens, 'lpTokenOut');
    }
  }

  void _requireInPool(XrplCurrencyAmount value, String name) {
    final candidate = _assetOf(value);
    if (candidate != asset && candidate != asset2) {
      throw ArgumentError(
        "$name must be one of the pool's two assets "
        '(${asset.toJson()} or ${asset2.toJson()}), but it is '
        '${candidate.toJson()}.',
      );
    }
  }

  static XrplAsset _assetOf(XrplCurrencyAmount value) {
    if (value.isXrp) return const XrplAsset.xrp();
    return XrplAsset.issued(currency: value.currency!, issuer: value.issuer!);
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
