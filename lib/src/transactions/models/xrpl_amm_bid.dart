import 'package:xrpl_flutter_sdk/src/transactions/values/xrpl_asset.dart';
import 'package:xrpl_flutter_sdk/src/transactions/values/xrpl_currency_amount.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_transaction.dart';

/// An `AMMBid` transaction: bids the pool's liquidity provider (LP)
/// tokens for the auction slot of an existing Automated Market Maker
/// (AMM) pool.
///
/// The winner of the slot trades against the pool at a discounted fee
/// for 24 hours, or until someone outbids it. The discounted fee is
/// normally one tenth of the pool's trading fee, and the winner can
/// also authorize up to four other accounts, [authAccounts], to trade
/// at the discounted fee. The winning bid is paid in the pool's LP
/// tokens, and what is paid is returned to the AMM, which reduces the
/// LP tokens in circulation.
///
/// The pool is identified by [asset] and [asset2], in any order.
/// [bidMin] and [bidMax] limit what the sender is willing to pay, in LP
/// tokens (their currency is the pool's LP token code and their issuer
/// is the AMM account, both reported by `ammInfo` as `lpToken`):
///
/// - [bidMin]: pay at least this much. Setting it higher makes it
///   harder for others to outbid the sender. If omitted, the sender
///   pays the minimum needed to win the slot.
/// - [bidMax]: pay at most this much. If winning costs more than this,
///   the transaction fails with `tecAMM_FAILED`. If omitted, the sender
///   pays as much as needed to win the slot.
///
/// This constructor validates the rules the official documentation
/// states for the transaction itself, and throws an [ArgumentError]
/// when one is broken:
///
/// - [asset] and [asset2] must be different assets.
/// - [bidMin] and [bidMax] must be LP tokens (an issued currency,
///   never XRP) and positive.
/// - [authAccounts] must have at most [maxAuthAccounts] (4) accounts,
///   and must not include the sending [account].
///
/// Rules that depend on the state of the ledger, or that the official
/// page does not state, are not checked here. The server rejects them
/// with its own result code: `terNO_AMM` (no such pool),
/// `tecAMM_EMPTY`, `tecAMM_FAILED` (the bid cannot win: not enough LP
/// tokens, or the price is above [bidMax]), `tecAMM_INVALID_TOKENS`
/// (the sender does not hold enough LP tokens for the slot price),
/// `temBAD_AMM_TOKENS` ([bidMin] or [bidMax] are not this pool's LP
/// tokens), `terNO_ACCOUNT` (an authorized account does not exist) and
/// `temMALFORMED`. The documentation does not say whether [bidMin] and
/// [bidMax] may be sent together, whether an account may repeat in
/// [authAccounts], or whether [authAccounts] may be empty, so none of
/// that is forbidden here.
///
/// The official page documents no flags for this transaction, so none
/// is sent. It also states no special transaction cost, so, like
/// `AMMDeposit`, `AMMWithdraw` and `AMMVote` and unlike `AMMCreate`, it
/// is expected to pay the normal cost and `autofill` needs no special
/// handling for it. The Testnet integration tests check this.
///
/// This only represents the transaction's *content*: it is not yet
/// signed or submitted.
///
/// Example:
/// ```dart
/// final bid = XrplAmmBid(
///   account: wallet.classicAddress,
///   asset: const XrplAsset.xrp(),
///   asset2: XrplAsset.issued(
///     currency: 'TST',
///     issuer: 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd',
///   ),
///   bidMax: XrplCurrencyAmount.issued(
///     currency: lpToken.currency,
///     issuer: lpToken.issuer,
///     value: '10',
///   ),
/// );
/// ```
///
/// See:
/// https://xrpl.org/docs/references/protocol/transactions/types/ammbid
class XrplAmmBid implements XrplTransaction {
  /// Creates an `AMMBid` transaction. [account], [asset], and [asset2]
  /// are required per the official specification; the rest is optional
  /// ([sequence], [fee] and [lastLedgerSequence] are typically filled
  /// in later by `autofill`).
  ///
  /// Throws an [ArgumentError] if any rule listed in this class's
  /// documentation is broken.
  XrplAmmBid({
    required this.account,
    required this.asset,
    required this.asset2,
    this.bidMin,
    this.bidMax,
    List<String>? authAccounts,
    this.sequence,
    this.fee,
    this.lastLedgerSequence,
  }) : authAccounts =
            authAccounts == null ? null : List.unmodifiable(authAccounts) {
    _validate();
  }

  /// The most accounts [authAccounts] may hold, per the official
  /// documentation: 4.
  static const int maxAuthAccounts = 4;

  /// The account bidding. It must hold LP tokens of the pool.
  @override
  final String account;

  /// One of the two assets identifying the pool.
  final XrplAsset asset;

  /// The other asset identifying the pool.
  final XrplAsset asset2;

  /// The least the sender will pay for the slot, in the pool's LP
  /// tokens, or `null` to pay the minimum needed to win.
  final XrplCurrencyAmount? bidMin;

  /// The most the sender will pay for the slot, in the pool's LP
  /// tokens, or `null` to pay as much as needed to win.
  final XrplCurrencyAmount? bidMax;

  /// Up to [maxAuthAccounts] additional accounts authorized to trade
  /// at the discounted fee, as classic addresses, or `null` for none.
  /// It cannot include [account]. The list is unmodifiable.
  final List<String>? authAccounts;

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
  XrplAmmBid copyWith({
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  }) {
    return XrplAmmBid(
      account: account,
      asset: asset,
      asset2: asset2,
      bidMin: bidMin,
      bidMax: bidMax,
      authAccounts: authAccounts,
      sequence: sequence ?? this.sequence,
      fee: fee ?? this.fee,
      lastLedgerSequence: lastLedgerSequence ?? this.lastLedgerSequence,
    );
  }

  /// Converts this transaction into the JSON shape XRPL expects,
  /// including the required `TransactionType` field. Fields left
  /// `null` are omitted entirely, not sent as `null`. Each of
  /// [authAccounts] is wrapped as `{'AuthAccount': {'Account': ...}}`,
  /// the shape the binary format expects.
  @override
  Map<String, dynamic> toJson() {
    return {
      'TransactionType': 'AMMBid',
      'Account': account,
      'Asset': asset.toJson(),
      'Asset2': asset2.toJson(),
      if (bidMin != null) 'BidMin': bidMin!.toJson(),
      if (bidMax != null) 'BidMax': bidMax!.toJson(),
      if (authAccounts != null)
        'AuthAccounts': [
          for (final authAccount in authAccounts!)
            {
              'AuthAccount': {'Account': authAccount},
            },
        ],
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

    final min = bidMin;
    final max = bidMax;
    if (min != null) _requireLpTokens(min, 'bidMin');
    if (max != null) _requireLpTokens(max, 'bidMax');

    final accounts = authAccounts;
    if (accounts != null) {
      if (accounts.length > maxAuthAccounts) {
        throw ArgumentError.value(
          accounts,
          'authAccounts',
          'must have at most $maxAuthAccounts accounts, but has '
              '${accounts.length}',
        );
      }
      if (accounts.contains(account)) {
        throw ArgumentError.value(
          account,
          'authAccounts',
          'must not include the sending account',
        );
      }
    }
  }

  static void _requireLpTokens(XrplCurrencyAmount value, String name) {
    if (value.isXrp) {
      throw ArgumentError.value(
        value.drops,
        name,
        'must be LP tokens (an issued currency), not XRP',
      );
    }
    final parsed = double.tryParse(value.value!);
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      throw ArgumentError.value(
        value.value,
        name,
        'must be a positive amount',
      );
    }
  }
}
