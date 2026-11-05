import 'package:xrpl_flutter_sdk/src/transactions/values/xrpl_asset.dart';
import 'package:xrpl_flutter_sdk/src/transactions/values/xrpl_currency_amount.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_transaction.dart';

/// An `AMMWithdraw` transaction: redeems the pool's liquidity provider
/// (LP) tokens and withdraws funds from an existing Automated Market
/// Maker (AMM) pool.
///
/// The pool is identified by [asset] and [asset2]. What is withdrawn
/// depends on the withdrawal mode, and the official specification
/// allows exactly seven, each with a fixed set of fields. Rather than
/// one constructor with many optional fields (where most combinations
/// are invalid), each mode has its own named constructor, so an
/// invalid combination cannot be written at all:
///
/// | Constructor | Fields | What it does |
/// |---|---|---|
/// | [XrplAmmWithdraw.lpToken] | `lpTokenIn` | Double-asset withdrawal redeeming that many LP tokens |
/// | [XrplAmmWithdraw.withdrawAll] | none | Double-asset withdrawal returning all your LP tokens |
/// | [XrplAmmWithdraw.oneAssetWithdrawAll] | `amount` | Single-asset withdrawal returning all your LP tokens |
/// | [XrplAmmWithdraw.singleAsset] | `amount` | Single-asset withdrawal of a specified amount |
/// | [XrplAmmWithdraw.twoAsset] | `amount`, `amount2` | Double-asset withdrawal of specified amounts of both assets |
/// | [XrplAmmWithdraw.oneAssetLpToken] | `amount`, `lpTokenIn` | Single-asset withdrawal redeeming that many LP tokens |
/// | [XrplAmmWithdraw.limitLpToken] | `amount`, `ePrice` | Single-asset withdrawal with a specified effective price |
///
/// Double-asset withdrawals are not subject to a pool fee. Single-asset
/// withdrawals are: the AMM charges a fee based on how much the
/// withdrawal shifts the balance of assets in the pool.
///
/// The official page states no special transaction cost for this
/// transaction, so, like `AMMDeposit` and unlike `AMMCreate`, it is
/// expected to pay the normal cost and `autofill` needs no special
/// handling for it. The Testnet integration tests check this.
///
/// Withdrawing the last of a pool's assets also deletes the pool: the
/// server tries to remove the AMM and its empty trust lines, and if
/// there are too many of them the AMM stays in the ledger in an empty
/// state.
///
/// Only rules that can be checked without ledger state are validated
/// at construction, each throwing an [ArgumentError]:
///
/// - [asset] and [asset2] must be different assets.
/// - Every amount must be positive, with one exception: the [amount] of
///   [XrplAmmWithdraw.oneAssetWithdrawAll] may be zero. The official
///   page says "the specified amount can be 0, meaning the transaction
///   succeeds if it withdraws any positive amount".
/// - [amount] and [amount2] must each be one of the pool's two assets,
///   and must not be the same asset as each other.
/// - [lpTokenIn] must be an issued currency (LP tokens are never XRP).
///
/// Everything that depends on the ledger is left to the server and
/// surfaces as its result code: `terNO_AMM` (no such pool),
/// `tecAMM_EMPTY`, `tecAMM_BALANCE`, `tecAMM_FAILED`,
/// `tecAMM_INVALID_TOKENS`, `tecFROZEN`, `tecNO_AUTH`, and others.
///
/// Known limitation: [ePrice] is only checked to be positive. The
/// official page describes it as the minimum effective price, in LP
/// tokens, to pay per unit of the asset to withdraw, and this SDK does
/// not check which asset it is expressed in.
///
/// See:
/// https://xrpl.org/docs/references/protocol/transactions/types/ammwithdraw
class XrplAmmWithdraw implements XrplTransaction {
  XrplAmmWithdraw._({
    required this.account,
    required this.asset,
    required this.asset2,
    required this.flags,
    this.amount,
    this.amount2,
    this.ePrice,
    this.lpTokenIn,
    this.sequence,
    this.fee,
    this.lastLedgerSequence,
  }) {
    _validate();
  }

  /// Redeems exactly [lpTokenIn] LP tokens in a double-asset
  /// withdrawal (`tfLPToken`).
  ///
  /// Throws an [ArgumentError] if any rule listed in this class's
  /// documentation is broken.
  XrplAmmWithdraw.lpToken({
    required String account,
    required XrplAsset asset,
    required XrplAsset asset2,
    required XrplCurrencyAmount lpTokenIn,
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  }) : this._(
          account: account,
          asset: asset,
          asset2: asset2,
          flags: tfLpToken,
          lpTokenIn: lpTokenIn,
          sequence: sequence,
          fee: fee,
          lastLedgerSequence: lastLedgerSequence,
        );

  /// Redeems all of the sender's LP tokens in a double-asset
  /// withdrawal (`tfWithdrawAll`). It takes no amounts.
  ///
  /// If the sender holds every LP token, this empties the pool and the
  /// server deletes it.
  ///
  /// Throws an [ArgumentError] if [asset] and [asset2] are the same.
  XrplAmmWithdraw.withdrawAll({
    required String account,
    required XrplAsset asset,
    required XrplAsset asset2,
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  }) : this._(
          account: account,
          asset: asset,
          asset2: asset2,
          flags: tfWithdrawAll,
          sequence: sequence,
          fee: fee,
          lastLedgerSequence: lastLedgerSequence,
        );

  /// Redeems all of the sender's LP tokens in a single-asset
  /// withdrawal of the asset [amount] names (`tfOneAssetWithdrawAll`).
  ///
  /// [amount] may be zero: the transaction then succeeds if it
  /// withdraws any positive amount.
  ///
  /// Throws an [ArgumentError] if any rule listed in this class's
  /// documentation is broken.
  XrplAmmWithdraw.oneAssetWithdrawAll({
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
          flags: tfOneAssetWithdrawAll,
          amount: amount,
          sequence: sequence,
          fee: fee,
          lastLedgerSequence: lastLedgerSequence,
        );

  /// Withdraws a specified [amount] of one pool asset
  /// (`tfSingleAsset`).
  ///
  /// Throws an [ArgumentError] if any rule listed in this class's
  /// documentation is broken.
  XrplAmmWithdraw.singleAsset({
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

  /// Withdraws specified amounts of both pool assets, [amount] and
  /// [amount2] (`tfTwoAsset`).
  ///
  /// Throws an [ArgumentError] if any rule listed in this class's
  /// documentation is broken.
  XrplAmmWithdraw.twoAsset({
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

  /// Withdraws one pool asset, [amount], redeeming [lpTokenIn] LP
  /// tokens (`tfOneAssetLPToken`).
  ///
  /// Throws an [ArgumentError] if any rule listed in this class's
  /// documentation is broken.
  XrplAmmWithdraw.oneAssetLpToken({
    required String account,
    required XrplAsset asset,
    required XrplAsset asset2,
    required XrplCurrencyAmount amount,
    required XrplCurrencyAmount lpTokenIn,
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  }) : this._(
          account: account,
          asset: asset,
          asset2: asset2,
          flags: tfOneAssetLpToken,
          amount: amount,
          lpTokenIn: lpTokenIn,
          sequence: sequence,
          fee: fee,
          lastLedgerSequence: lastLedgerSequence,
        );

  /// Withdraws one pool asset, [amount], at a specified effective
  /// price, [ePrice] (`tfLimitLPToken`).
  ///
  /// Throws an [ArgumentError] if any rule listed in this class's
  /// documentation is broken.
  XrplAmmWithdraw.limitLpToken({
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

  /// The `Flags` value of the `tfWithdrawAll` mode.
  static const tfWithdrawAll = 0x00020000;

  /// The `Flags` value of the `tfOneAssetWithdrawAll` mode.
  static const tfOneAssetWithdrawAll = 0x00040000;

  /// The `Flags` value of the `tfSingleAsset` mode.
  static const tfSingleAsset = 0x00080000;

  /// The `Flags` value of the `tfTwoAsset` mode.
  static const tfTwoAsset = 0x00100000;

  /// The `Flags` value of the `tfOneAssetLPToken` mode.
  static const tfOneAssetLpToken = 0x00200000;

  /// The `Flags` value of the `tfLimitLPToken` mode.
  static const tfLimitLpToken = 0x00400000;

  /// The account withdrawing from the pool.
  @override
  final String account;

  /// One of the two assets identifying the pool.
  final XrplAsset asset;

  /// The other asset identifying the pool.
  final XrplAsset asset2;

  /// The `Flags` value for this transaction's withdrawal mode: exactly
  /// one of [tfLpToken], [tfWithdrawAll], [tfOneAssetWithdrawAll],
  /// [tfSingleAsset], [tfTwoAsset], [tfOneAssetLpToken] or
  /// [tfLimitLpToken].
  final int flags;

  /// The amount of one pool asset to withdraw, or `null` in the
  /// [XrplAmmWithdraw.lpToken] and [XrplAmmWithdraw.withdrawAll]
  /// modes.
  final XrplCurrencyAmount? amount;

  /// The amount of the other pool asset to withdraw, only in the
  /// [XrplAmmWithdraw.twoAsset] mode.
  final XrplCurrencyAmount? amount2;

  /// The effective price of the withdrawal, only in the
  /// [XrplAmmWithdraw.limitLpToken] mode.
  final XrplCurrencyAmount? ePrice;

  /// How many LP tokens to redeem, only in the [XrplAmmWithdraw.lpToken]
  /// and [XrplAmmWithdraw.oneAssetLpToken] modes. Its currency is the
  /// pool's LP token code and its issuer is the AMM account (both are
  /// reported by `ammInfo` as `lpToken`).
  final XrplCurrencyAmount? lpTokenIn;

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
  XrplAmmWithdraw copyWith({
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  }) {
    return XrplAmmWithdraw._(
      account: account,
      asset: asset,
      asset2: asset2,
      flags: flags,
      amount: amount,
      amount2: amount2,
      ePrice: ePrice,
      lpTokenIn: lpTokenIn,
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
      'TransactionType': 'AMMWithdraw',
      'Account': account,
      'Asset': asset.toJson(),
      'Asset2': asset2.toJson(),
      if (amount != null) 'Amount': amount!.toJson(),
      if (amount2 != null) 'Amount2': amount2!.toJson(),
      if (ePrice != null) 'EPrice': ePrice!.toJson(),
      if (lpTokenIn != null) 'LPTokenIn': lpTokenIn!.toJson(),
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
    final lpTokens = lpTokenIn;

    if (firstAmount != null) {
      // tfOneAssetWithdrawAll is the only mode whose Amount may be 0.
      _requireAmount(
        firstAmount,
        'amount',
        allowZero: flags == tfOneAssetWithdrawAll,
      );
      _requireInPool(firstAmount, 'amount');
    }
    if (secondAmount != null) {
      _requireAmount(secondAmount, 'amount2');
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
      _requireAmount(price, 'ePrice');
    }
    if (lpTokens != null) {
      if (lpTokens.isXrp) {
        throw ArgumentError.value(
          lpTokens.drops,
          'lpTokenIn',
          'must be an LP token (an issued currency), not XRP',
        );
      }
      _requireAmount(lpTokens, 'lpTokenIn');
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

  static void _requireAmount(
    XrplCurrencyAmount value,
    String name, {
    bool allowZero = false,
  }) {
    final bool valid;
    if (value.isXrp) {
      final drops = BigInt.tryParse(value.drops!);
      valid = drops != null &&
          (allowZero ? drops >= BigInt.zero : drops > BigInt.zero);
    } else {
      final parsed = double.tryParse(value.value!);
      valid = parsed != null &&
          parsed.isFinite &&
          (allowZero ? parsed >= 0 : parsed > 0);
    }
    if (!valid) {
      throw ArgumentError.value(
        value.isXrp ? value.drops : value.value,
        name,
        allowZero ? 'must not be negative' : 'must be a positive amount',
      );
    }
  }
}
