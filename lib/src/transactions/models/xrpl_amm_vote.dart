import 'package:xrpl_flutter_sdk/src/transactions/models/xrpl_amm_create.dart';
import 'package:xrpl_flutter_sdk/src/transactions/values/xrpl_asset.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_transaction.dart';

/// An `AMMVote` transaction: votes on the trading fee of an existing
/// Automated Market Maker (AMM) pool.
///
/// The pool is identified by [asset] and [asset2], in any order, and
/// [tradingFee] is the fee the sender proposes, in units of 1/100,000
/// (1 equals 0.001%). Only liquidity providers can vote, and each vote
/// weighs as much as the share of the pool's LP tokens the voter holds.
/// Each new vote recalculates the pool's fee as the average of the
/// latest votes weighted by those shares. Up to eight votes are counted:
/// the ones from the accounts holding the most LP tokens.
///
/// This constructor validates the rules the official documentation
/// states for the transaction itself, and throws an [ArgumentError]
/// when one is broken:
///
/// - [asset] and [asset2] must be different assets.
/// - [tradingFee] must be between 0 and [maxTradingFee] (1000, which is
///   a 1% fee).
///
/// Rules that depend on the state of the ledger are not checked here.
/// The server rejects them with its own result code: `terNO_AMM` (no
/// such pool), `tecAMM_EMPTY`, `tecAMM_INVALID_TOKENS` (the sender holds
/// no LP tokens of the pool, so it cannot vote), `tecAMM_FAILED_VOTE`
/// (eight accounts holding more LP tokens than the sender have already
/// voted) and `temBAD_FEE`.
///
/// The official page documents no flags for this transaction, so none
/// is sent. It also states no special transaction cost, so, like
/// `AMMDeposit` and `AMMWithdraw` and unlike `AMMCreate`, it is expected
/// to pay the normal cost and `autofill` needs no special handling for
/// it. The Testnet integration tests check this.
///
/// This only represents the transaction's *content*: it is not yet
/// signed or submitted.
///
/// Example:
/// ```dart
/// final vote = XrplAmmVote(
///   account: wallet.classicAddress,
///   asset: const XrplAsset.xrp(),
///   asset2: XrplAsset.issued(
///     currency: 'TST',
///     issuer: 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd',
///   ),
///   tradingFee: 300, // 0.3%
/// );
/// ```
///
/// See:
/// https://xrpl.org/docs/references/protocol/transactions/types/ammvote
class XrplAmmVote implements XrplTransaction {
  /// Creates an `AMMVote` transaction. [account], [asset], [asset2],
  /// and [tradingFee] are required per the official specification; the
  /// rest is optional and typically filled in later by `autofill`.
  ///
  /// Throws an [ArgumentError] if any rule listed in this class's
  /// documentation is broken.
  XrplAmmVote({
    required this.account,
    required this.asset,
    required this.asset2,
    required this.tradingFee,
    this.sequence,
    this.fee,
    this.lastLedgerSequence,
  }) {
    _validate();
  }

  /// The highest `TradingFee` the network accepts: 1000, which is a 1%
  /// fee. It is the same limit `AMMCreate` has, so this reuses that
  /// constant instead of repeating the number.
  static const int maxTradingFee = XrplAmmCreate.maxTradingFee;

  /// The account voting. It must hold LP tokens of the pool.
  @override
  final String account;

  /// One of the two assets identifying the pool.
  final XrplAsset asset;

  /// The other asset identifying the pool.
  final XrplAsset asset2;

  /// The fee this vote proposes for the pool, in units of 1/100,000
  /// (1 equals 0.001%), from 0 to [maxTradingFee].
  final int tradingFee;

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
  XrplAmmVote copyWith({
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  }) {
    return XrplAmmVote(
      account: account,
      asset: asset,
      asset2: asset2,
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
      'TransactionType': 'AMMVote',
      'Account': account,
      'Asset': asset.toJson(),
      'Asset2': asset2.toJson(),
      'TradingFee': tradingFee,
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
    if (tradingFee < 0 || tradingFee > maxTradingFee) {
      throw ArgumentError.value(
        tradingFee,
        'tradingFee',
        'must be between 0 and $maxTradingFee',
      );
    }
  }
}
