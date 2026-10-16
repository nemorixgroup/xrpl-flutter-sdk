import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_connection_exception.dart';
import 'package:xrpl_flutter_sdk/src/transactions/values/xrpl_asset.dart';
import 'package:xrpl_flutter_sdk/src/transactions/values/xrpl_currency_amount.dart';

/// Requests the current state of an Automated Market Maker pool with
/// `amm_info`.
///
/// Identify the pool in one of two ways: by its two assets ([asset]
/// and [asset2], which must be given together), or by the pool's own
/// account ([ammAccount]). The official documentation requires one of
/// those two forms; it does not say what happens when both are given,
/// so this function does not forbid it and leaves that to the server.
///
/// [account] is optional: when set, the `lpToken` in the result is the
/// balance of that liquidity provider, not the pool's total.
/// [ledgerHash] and [ledgerIndex] select the ledger version to read
/// ([ledgerIndex] is a ledger number or a shortcut string such as
/// `'validated'`).
///
/// Throws an [ArgumentError] if only one of [asset] and [asset2] is
/// given, if neither [ammAccount] nor the asset pair is given, or if
/// [ledgerIndex] is neither an `int` nor a `String`.
///
/// Throws an [XrplConnectionException] if not connected, if the
/// request times out, if the server returns an error (for example
/// `actNotFound` when no AMM exists for that pair), or if the
/// response doesn't have the expected shape.
///
/// Example:
/// ```dart
/// final info = await ammInfo(
///   connection,
///   asset: const XrplAsset.xrp(),
///   asset2: XrplAsset.issued(
///     currency: 'TST',
///     issuer: 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd',
///   ),
///   ledgerIndex: 'validated',
/// );
/// print(info.tradingFee); // e.g. 500, in units of 1/100,000
/// ```
///
/// See:
/// https://xrpl.org/docs/references/http-websocket-apis/public-api-methods/path-and-order-book-methods/amm_info
Future<XrplAmmInfo> ammInfo(
  XrplConnection connection, {
  XrplAsset? asset,
  XrplAsset? asset2,
  String? ammAccount,
  String? account,
  String? ledgerHash,
  Object? ledgerIndex,
}) async {
  if ((asset == null) != (asset2 == null)) {
    throw ArgumentError(
      'asset and asset2 must be provided together, or both omitted.',
    );
  }
  if (ammAccount == null && asset == null) {
    throw ArgumentError(
      'amm_info needs either ammAccount, or both asset and asset2.',
    );
  }
  if (ledgerIndex != null && ledgerIndex is! int && ledgerIndex is! String) {
    throw ArgumentError.value(
      ledgerIndex,
      'ledgerIndex',
      'must be an int or a String',
    );
  }

  final response = await connection.request('amm_info', {
    if (asset != null) 'asset': asset.toJson(),
    if (asset2 != null) 'asset2': asset2.toJson(),
    if (ammAccount != null) 'amm_account': ammAccount,
    if (account != null) 'account': account,
    if (ledgerHash != null) 'ledger_hash': ledgerHash,
    if (ledgerIndex != null) 'ledger_index': ledgerIndex,
  });

  final resultRaw = response['result'];
  if (resultRaw is! Map<String, dynamic>) {
    throw const XrplConnectionException(
      'Unexpected amm_info response shape: missing or invalid '
      '"result" field.',
    );
  }
  return XrplAmmInfo.fromJson(resultRaw);
}

/// The state of an AMM pool, as reported by `amm_info`.
///
/// See:
/// https://xrpl.org/docs/references/http-websocket-apis/public-api-methods/path-and-order-book-methods/amm_info
class XrplAmmInfo {
  /// Creates an AMM description. Normally built by [ammInfo] or
  /// [XrplAmmInfo.fromJson], not by hand.
  const XrplAmmInfo({
    required this.account,
    required this.amount,
    required this.amount2,
    required this.lpToken,
    required this.tradingFee,
    this.assetFrozen,
    this.asset2Frozen,
    this.auctionSlot,
    this.voteSlots = const [],
    this.validated = false,
    this.ledgerIndex,
    this.ledgerCurrentIndex,
    this.ledgerHash,
  });

  /// Builds an [XrplAmmInfo] from the `result` object of an `amm_info`
  /// response.
  ///
  /// Throws an [XrplConnectionException] if a required field is
  /// missing or has an unexpected type.
  factory XrplAmmInfo.fromJson(Map<String, dynamic> result) {
    final amm = _asMap(result['amm'], 'amm');
    final auctionRaw = amm['auction_slot'];
    final votesRaw = amm['vote_slots'];

    return XrplAmmInfo(
      account: _asString(amm['account'], 'amm.account'),
      amount: _asAmount(amm['amount'], 'amm.amount'),
      amount2: _asAmount(amm['amount2'], 'amm.amount2'),
      lpToken: _asAmount(amm['lp_token'], 'amm.lp_token'),
      tradingFee: _asInt(amm['trading_fee'], 'amm.trading_fee'),
      assetFrozen: _asOptionalBool(amm['asset_frozen'], 'amm.asset_frozen'),
      asset2Frozen: _asOptionalBool(amm['asset2_frozen'], 'amm.asset2_frozen'),
      auctionSlot: auctionRaw == null
          ? null
          : XrplAmmAuctionSlot._fromJson(
              _asMap(auctionRaw, 'amm.auction_slot'),
            ),
      voteSlots: votesRaw == null
          ? const []
          : _asList(votesRaw, 'amm.vote_slots')
              .map(
                (slot) => XrplAmmVoteSlot._fromJson(
                  _asMap(slot, 'amm.vote_slots[]'),
                ),
              )
              .toList(),
      validated: _asOptionalBool(result['validated'], 'validated') ?? false,
      ledgerIndex: _asOptionalInt(result['ledger_index'], 'ledger_index'),
      ledgerCurrentIndex: _asOptionalInt(
        result['ledger_current_index'],
        'ledger_current_index',
      ),
      ledgerHash: _asOptionalString(result['ledger_hash'], 'ledger_hash'),
    );
  }

  /// The pool's own account, which issues its LP tokens.
  final String account;

  /// The total of one of the pool's assets. It may be either `asset`
  /// or `asset2` from the request.
  final XrplCurrencyAmount amount;

  /// The total of the pool's other asset.
  final XrplCurrencyAmount amount2;

  /// The total LP tokens outstanding, or, if `account` was given in
  /// the request, that liquidity provider's balance.
  final XrplCurrencyAmount lpToken;

  /// The pool's current trading fee, in units of 1/100,000 (1 equals
  /// 0.001%).
  final int tradingFee;

  /// Whether the [amount] currency is frozen. `null` when it is XRP
  /// (the server omits the field).
  final bool? assetFrozen;

  /// Whether the [amount2] currency is frozen. `null` when it is XRP
  /// (the server omits the field).
  final bool? asset2Frozen;

  /// The current holder of the auction slot, or `null` if the server
  /// omitted it.
  final XrplAmmAuctionSlot? auctionSlot;

  /// The current trading fee votes. Empty if the server omitted them.
  final List<XrplAmmVoteSlot> voteSlots;

  /// Whether the data comes from a validated ledger. `false` means it
  /// is pending and may change.
  final bool validated;

  /// The index of the validated ledger used, when the server reports
  /// one.
  final int? ledgerIndex;

  /// The index of the in-progress ledger used, when the server
  /// reports one instead of [ledgerIndex].
  final int? ledgerCurrentIndex;

  /// The hash of the ledger version used, when the server reports
  /// one.
  final String? ledgerHash;
}

/// The auction slot of an AMM pool: who currently holds the discounted
/// trading fee, until when, and at what price.
class XrplAmmAuctionSlot {
  /// Creates an auction slot description.
  const XrplAmmAuctionSlot({
    required this.account,
    required this.discountedFee,
    required this.expiration,
    required this.price,
    required this.timeInterval,
    this.authAccounts = const [],
  });

  factory XrplAmmAuctionSlot._fromJson(Map<String, dynamic> json) {
    final authRaw = json['auth_accounts'];
    return XrplAmmAuctionSlot(
      account: _asString(json['account'], 'auction_slot.account'),
      authAccounts: authRaw == null
          ? const []
          : _asList(authRaw, 'auction_slot.auth_accounts')
              .map(
                (entry) => _asString(
                  _asMap(entry, 'auction_slot.auth_accounts[]')['account'],
                  'auction_slot.auth_accounts[].account',
                ),
              )
              .toList(),
      discountedFee: _asInt(
        json['discounted_fee'],
        'auction_slot.discounted_fee',
      ),
      expiration: _asString(json['expiration'], 'auction_slot.expiration'),
      price: _asAmount(json['price'], 'auction_slot.price'),
      timeInterval: _asInt(
        json['time_interval'],
        'auction_slot.time_interval',
      ),
    );
  }

  /// The owner of the auction slot.
  final String account;

  /// The accounts that also get the discounted fee.
  final List<String> authAccounts;

  /// The trading fee for the slot holder and the authorized accounts,
  /// one tenth of the pool's normal trading fee.
  final int discountedFee;

  /// When the slot stops applying, as the server reports it.
  final String expiration;

  /// What was paid, in LP tokens, to win the slot.
  final XrplCurrencyAmount price;

  /// The current 72-minute interval of the slot, from 0 to 19.
  final int timeInterval;
}

/// One liquidity provider's vote on the pool's trading fee.
class XrplAmmVoteSlot {
  /// Creates a vote slot description.
  const XrplAmmVoteSlot({
    required this.account,
    required this.tradingFee,
    required this.voteWeight,
  });

  factory XrplAmmVoteSlot._fromJson(Map<String, dynamic> json) {
    return XrplAmmVoteSlot(
      account: _asString(json['account'], 'vote_slots[].account'),
      tradingFee: _asInt(json['trading_fee'], 'vote_slots[].trading_fee'),
      voteWeight: _asInt(json['vote_weight'], 'vote_slots[].vote_weight'),
    );
  }

  /// The liquidity provider that voted.
  final String account;

  /// The trading fee voted for, in units of 1/100,000.
  final int tradingFee;

  /// The vote's weight, proportional to the provider's share of the LP
  /// tokens (1000 means a 1% share).
  final int voteWeight;
}

XrplConnectionException _badField(String field) {
  return XrplConnectionException(
    'Unexpected amm_info response shape: missing or invalid "$field" field.',
  );
}

Map<String, dynamic> _asMap(Object? value, String field) {
  if (value is! Map<String, dynamic>) throw _badField(field);
  return value;
}

List<dynamic> _asList(Object? value, String field) {
  if (value is! List<dynamic>) throw _badField(field);
  return value;
}

String _asString(Object? value, String field) {
  if (value is! String) throw _badField(field);
  return value;
}

int _asInt(Object? value, String field) {
  if (value is! int) throw _badField(field);
  return value;
}

String? _asOptionalString(Object? value, String field) {
  return value == null ? null : _asString(value, field);
}

int? _asOptionalInt(Object? value, String field) {
  return value == null ? null : _asInt(value, field);
}

bool? _asOptionalBool(Object? value, String field) {
  if (value == null) return null;
  if (value is! bool) throw _badField(field);
  return value;
}

/// Reads a currency amount in either shape the server uses: a drops
/// string for XRP, or a `{currency, issuer, value}` object for an
/// issued token.
XrplCurrencyAmount _asAmount(Object? value, String field) {
  if (value is String) return XrplCurrencyAmount.xrp(value);
  if (value is Map<String, dynamic>) {
    return XrplCurrencyAmount.issued(
      currency: _asString(value['currency'], '$field.currency'),
      issuer: _asString(value['issuer'], '$field.issuer'),
      value: _asString(value['value'], '$field.value'),
    );
  }
  throw _badField(field);
}
