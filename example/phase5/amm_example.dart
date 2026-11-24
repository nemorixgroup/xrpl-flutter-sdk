// Phase 5
//  - 0.4.3-dev: AMMCreate, amm_info.
//  - 0.4.4-dev: AMMDeposit.
//  - 0.4.5-dev: AMMWithdraw.
//  - 0.4.6-dev: AMMVote.
//  - 0.4.7-dev: AMMBid.
//
// Demonstrates XRPL's native Automated Market Maker: creating a
// liquidity pool for an asset pair with XrplAmmCreate, reading it back
// with ammInfo, adding liquidity to it with XrplAmmDeposit, taking it
// out with XrplAmmWithdraw, voting on its trading fee with
// XrplAmmVote, and bidding for its auction slot with XrplAmmBid. All of
// them use the same build -> autofill -> sign -> submitAndWait pipeline
// used throughout Phases 4 and 5.
//
// Creating a pool needs more setup than any earlier transaction:
//   1. The token issuer must enable Default Ripple, otherwise the
//      server rejects the pool with terNO_RIPPLE.
//   2. The pool creator must HOLD the token (an issuer cannot hold
//      its own token), so two accounts are needed: issuer and holder.
//   3. The holder opens a trust line (XrplTrustSet) and receives the
//      token by crossing an offer the issuer posts (XrplOfferCreate).
//
// Fee note: AMMCreate must destroy at least the owner reserve. When
// no fee is set, autofill reads it from the network (server_state,
// reserve_inc), so there is nothing to configure here. AMMDeposit,
// AMMWithdraw, AMMVote and AMMBid, in contrast, pay the normal
// transaction cost.
//
// Deposit note: XrplAmmDeposit has one named constructor per deposit
// mode (singleAsset, twoAsset, lpToken, oneAssetLpToken, limitLpToken,
// twoAssetIfEmpty), so an invalid mix of fields does not compile. The
// last mode only works on an EMPTY pool and is not shown here.
//
// Withdraw note: XrplAmmWithdraw works the same way, with one named
// constructor per mode (lpToken, withdrawAll, oneAssetWithdrawAll,
// singleAsset, twoAsset, oneAssetLpToken, limitLpToken). This file
// shows lpToken, singleAsset and withdrawAll. Withdrawing everything
// from a pool deletes it.
//
// Vote note: XrplAmmVote has a single form, because AMMVote has no
// modes. Only liquidity providers can vote, and each vote weighs as
// much as the share of the pool's LP tokens the voter holds. The pool's
// trading fee is the average of the latest votes weighted by those
// shares.
//
// Bid note: XrplAmmBid also has a single form. A liquidity provider
// bids LP tokens for the pool's auction slot; the winner trades against
// the pool at a discounted fee (one tenth of the normal fee) for 24
// hours, or until someone outbids it, and can authorize up to four more
// accounts to share that fee. bidMin and bidMax, both optional, limit
// what the bidder is willing to pay, in the pool's own LP tokens.
//
// Full technical decisions:
// https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk/phase-5

import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

// Temporary, example-only AccountSet that sets one account flag.
// The SDK has no public AccountSet model yet (planned for Phase 8,
// Account Security), so this file defines the minimum it needs.
class _SetAccountFlag implements XrplTransaction {
  const _SetAccountFlag({
    required this.account,
    required this.setFlag,
    this.sequence,
    this.fee,
    this.lastLedgerSequence,
  });

  @override
  final String account;
  final int setFlag;
  @override
  final int? sequence;
  @override
  final String? fee;
  @override
  final int? lastLedgerSequence;

  @override
  _SetAccountFlag copyWith({
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  }) {
    return _SetAccountFlag(
      account: account,
      setFlag: setFlag,
      sequence: sequence ?? this.sequence,
      fee: fee ?? this.fee,
      lastLedgerSequence: lastLedgerSequence ?? this.lastLedgerSequence,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'TransactionType': 'AccountSet',
        'Account': account,
        'SetFlag': setFlag,
        if (sequence != null) 'Sequence': sequence,
        if (fee != null) 'Fee': fee,
        if (lastLedgerSequence != null)
          'LastLedgerSequence': lastLedgerSequence,
      };
}

const _asfDefaultRipple = 8;

// Funds an issuer and a holder, and leaves the holder owning 100 TST
// issued by the issuer, which is what a pool creator needs.
Future<({XrplWallet issuer, XrplWallet holder})> _prepareTokenHolder(
  XrplConnection connection,
) async {
  final issuer = await fundTestWallet(connection);
  final holder = await fundTestWallet(connection);
  print('Issuer: ${issuer.classicAddress}');
  print('Holder: ${holder.classicAddress}');

  // 1. The issuer enables Default Ripple.
  await sendTransaction(
    connection,
    _SetAccountFlag(
      account: issuer.classicAddress,
      setFlag: _asfDefaultRipple,
    ),
    issuer,
  );

  // 2. The holder trusts the issuer for TST.
  await sendTransaction(
    connection,
    XrplTrustSet(
      account: holder.classicAddress,
      currency: 'TST',
      issuer: issuer.classicAddress,
      limitValue: '1000',
    ),
    holder,
  );

  // 3. The issuer sells 100 TST for 10 XRP and the holder takes it.
  await sendTransaction(
    connection,
    XrplOfferCreate(
      account: issuer.classicAddress,
      takerGets: XrplCurrencyAmount.issued(
        currency: 'TST',
        issuer: issuer.classicAddress,
        value: '100',
      ),
      takerPays: const XrplCurrencyAmount.xrp('10000000'),
    ),
    issuer,
  );
  await sendTransaction(
    connection,
    XrplOfferCreate(
      account: holder.classicAddress,
      takerGets: const XrplCurrencyAmount.xrp('10000000'),
      takerPays: XrplCurrencyAmount.issued(
        currency: 'TST',
        issuer: issuer.classicAddress,
        value: '100',
      ),
    ),
    holder,
  );

  return (issuer: issuer, holder: holder);
}

String _describe(XrplCurrencyAmount amount) {
  return amount.isXrp
      ? '${amount.drops} drops of XRP'
      : '${amount.value} ${amount.currency}';
}

Future<void> createAmmExample() async {
  final connection = XrplConnection(XrplEndpoint.testnet);
  await connection.connect();

  final accounts = await _prepareTokenHolder(connection);

  // Seed the pool with 5 XRP and 50 TST, and a 0.5% trading fee.
  // TradingFee is in units of 1/100000, so 500 = 0.5% (maximum 1000).
  // No Fee is set: autofill uses the network's owner reserve.
  final ammCreate = XrplAmmCreate(
    account: accounts.holder.classicAddress,
    amount: const XrplCurrencyAmount.xrp('5000000'),
    amount2: XrplCurrencyAmount.issued(
      currency: 'TST',
      issuer: accounts.issuer.classicAddress,
      value: '50',
    ),
    tradingFee: 500,
  );

  final result = await sendTransaction(
    connection,
    ammCreate,
    accounts.holder,
  );
  final meta = result['meta'] as Map<String, dynamic>;
  print('Result: ${meta['TransactionResult']}');
  print('Transaction hash: ${result['hash']}');
  print('Fee paid (drops): ${result['Fee']}');

  await connection.disconnect();
}

Future<void> ammInfoExample() async {
  final connection = XrplConnection(XrplEndpoint.testnet);
  await connection.connect();

  final accounts = await _prepareTokenHolder(connection);

  await sendTransaction(
    connection,
    XrplAmmCreate(
      account: accounts.holder.classicAddress,
      amount: const XrplCurrencyAmount.xrp('5000000'),
      amount2: XrplCurrencyAmount.issued(
        currency: 'TST',
        issuer: accounts.issuer.classicAddress,
        value: '50',
      ),
      tradingFee: 500,
    ),
    accounts.holder,
  );

  // Look the pool up by its asset pair. The order of the two assets
  // does not matter to the server.
  final info = await ammInfo(
    connection,
    asset: const XrplAsset.xrp(),
    asset2: XrplAsset.issued(
      currency: 'TST',
      issuer: accounts.issuer.classicAddress,
    ),
    ledgerIndex: 'validated',
  );

  print('AMM account: ${info.account}');
  print('Pool holds: ${_describe(info.amount)} and ${_describe(info.amount2)}');
  print('LP tokens: ${_describe(info.lpToken)}');
  print('Trading fee: ${info.tradingFee} (1/100000 units)');
  print('Validated ledger data: ${info.validated}');

  // The same pool can also be read by the AMM account itself.
  final byAccount = await ammInfo(connection, ammAccount: info.account);
  print('Looked up by account: ${byAccount.account == info.account}');

  await connection.disconnect();
}

// Reads the XRP/TST pool and prints what it holds, so each deposit's
// effect is visible. Returns the info so the caller can reuse it.
Future<XrplAmmInfo> _printPool(
  XrplConnection connection,
  XrplWallet issuer,
  String label,
) async {
  final info = await ammInfo(
    connection,
    asset: const XrplAsset.xrp(),
    asset2: XrplAsset.issued(
      currency: 'TST',
      issuer: issuer.classicAddress,
    ),
    ledgerIndex: 'validated',
  );
  print('$label: ${_describe(info.amount)} + ${_describe(info.amount2)}');
  print('$label LP tokens in circulation: ${info.lpToken.value}');
  return info;
}

Future<void> depositAmmExample() async {
  final connection = XrplConnection(XrplEndpoint.testnet);
  await connection.connect();

  final accounts = await _prepareTokenHolder(connection);
  final holder = accounts.holder;

  // Start from a real pool: 5 XRP and 50 TST.
  await sendTransaction(
    connection,
    XrplAmmCreate(
      account: holder.classicAddress,
      amount: const XrplCurrencyAmount.xrp('5000000'),
      amount2: XrplCurrencyAmount.issued(
        currency: 'TST',
        issuer: accounts.issuer.classicAddress,
        value: '50',
      ),
      tradingFee: 500,
    ),
    holder,
  );

  // The pool is identified by its two assets, in any order.
  const xrp = XrplAsset.xrp();
  final tst = XrplAsset.issued(
    currency: 'TST',
    issuer: accounts.issuer.classicAddress,
  );

  await _printPool(connection, accounts.issuer, 'Before');

  // ---- Mode 1: single asset ----
  // Deposit only XRP. The pool takes a fee out of the LP tokens
  // minted, because a one-sided deposit changes the pool's balance.
  final single = await sendTransaction(
    connection,
    XrplAmmDeposit.singleAsset(
      account: holder.classicAddress,
      asset: xrp,
      asset2: tst,
      amount: const XrplCurrencyAmount.xrp('1000000'),
    ),
    holder,
  );
  final singleMeta = single['meta'] as Map<String, dynamic>;
  print('Single asset: ${singleMeta['TransactionResult']}');
  // Unlike AMMCreate, AMMDeposit pays the normal transaction cost.
  print('Fee paid (drops): ${single['Fee']}');
  await _printPool(connection, accounts.issuer, 'After single asset');

  // ---- Mode 2: two assets ----
  // Deposit both assets in the pool's current proportion. Two-asset
  // deposits pay no pool fee. The amounts are an upper bound: the
  // server uses whatever fits the pool's ratio.
  final two = await sendTransaction(
    connection,
    XrplAmmDeposit.twoAsset(
      account: holder.classicAddress,
      asset: xrp,
      asset2: tst,
      amount: const XrplCurrencyAmount.xrp('500000'),
      amount2: XrplCurrencyAmount.issued(
        currency: 'TST',
        issuer: accounts.issuer.classicAddress,
        value: '5',
      ),
    ),
    holder,
  );
  final twoMeta = two['meta'] as Map<String, dynamic>;
  print('Two assets: ${twoMeta['TransactionResult']}');
  final afterTwo = await _printPool(
    connection,
    accounts.issuer,
    'After two assets',
  );

  // ---- Mode 3: exact LP tokens ----
  // Ask for exactly 10 LP tokens and let the pool take both assets in
  // proportion. The LP token currency and issuer come from ammInfo,
  // never from hand-built codes.
  final lp = afterTwo.lpToken;
  final exact = await sendTransaction(
    connection,
    XrplAmmDeposit.lpToken(
      account: holder.classicAddress,
      asset: xrp,
      asset2: tst,
      lpTokenOut: XrplCurrencyAmount.issued(
        currency: lp.currency.toString(),
        issuer: lp.issuer.toString(),
        value: '10',
      ),
    ),
    holder,
  );
  final exactMeta = exact['meta'] as Map<String, dynamic>;
  print('Exact LP tokens: ${exactMeta['TransactionResult']}');
  await _printPool(connection, accounts.issuer, 'After exact LP tokens');

  await connection.disconnect();
}

Future<void> withdrawAmmExample() async {
  final connection = XrplConnection(XrplEndpoint.testnet);
  await connection.connect();

  final accounts = await _prepareTokenHolder(connection);
  final holder = accounts.holder;

  // Start from a real pool: 5 XRP and 50 TST. The holder is its only
  // liquidity provider, so it owns every LP token.
  await sendTransaction(
    connection,
    XrplAmmCreate(
      account: holder.classicAddress,
      amount: const XrplCurrencyAmount.xrp('5000000'),
      amount2: XrplCurrencyAmount.issued(
        currency: 'TST',
        issuer: accounts.issuer.classicAddress,
        value: '50',
      ),
      tradingFee: 500,
    ),
    holder,
  );

  // The pool is identified by its two assets, in any order.
  const xrp = XrplAsset.xrp();
  final tst = XrplAsset.issued(
    currency: 'TST',
    issuer: accounts.issuer.classicAddress,
  );

  final before = await _printPool(connection, accounts.issuer, 'Before');

  // ---- Mode 1: exact LP tokens ----
  // Give back exactly 10 LP tokens and receive both assets in
  // proportion. Double-asset withdrawals pay no pool fee. The LP token
  // currency and issuer come from ammInfo, never from hand-built codes.
  final lp = before.lpToken;
  final redeem = await sendTransaction(
    connection,
    XrplAmmWithdraw.lpToken(
      account: holder.classicAddress,
      asset: xrp,
      asset2: tst,
      lpTokenIn: XrplCurrencyAmount.issued(
        currency: lp.currency.toString(),
        issuer: lp.issuer.toString(),
        value: '10',
      ),
    ),
    holder,
  );
  final redeemMeta = redeem['meta'] as Map<String, dynamic>;
  print('Exact LP tokens: ${redeemMeta['TransactionResult']}');
  // Like AMMDeposit, AMMWithdraw pays the normal transaction cost.
  print('Fee paid (drops): ${redeem['Fee']}');
  await _printPool(connection, accounts.issuer, 'After exact LP tokens');

  // ---- Mode 2: single asset ----
  // Take out only XRP. The pool charges a fee, because a one-sided
  // withdrawal changes the pool's balance. The server rounds in the
  // pool's favor, so it may pay a drop or two less than requested.
  final single = await sendTransaction(
    connection,
    XrplAmmWithdraw.singleAsset(
      account: holder.classicAddress,
      asset: xrp,
      asset2: tst,
      amount: const XrplCurrencyAmount.xrp('500000'),
    ),
    holder,
  );
  final singleMeta = single['meta'] as Map<String, dynamic>;
  print('Single asset: ${singleMeta['TransactionResult']}');
  await _printPool(connection, accounts.issuer, 'After single asset');

  // ---- Mode 3: withdraw everything ----
  // Redeem every LP token the holder owns, for both assets. The holder
  // is the only provider, so the pool is emptied and the network
  // deletes it.
  final all = await sendTransaction(
    connection,
    XrplAmmWithdraw.withdrawAll(
      account: holder.classicAddress,
      asset: xrp,
      asset2: tst,
    ),
    holder,
  );
  final allMeta = all['meta'] as Map<String, dynamic>;
  print('Withdraw all: ${allMeta['TransactionResult']}');

  try {
    await ammInfo(connection, asset: xrp, asset2: tst);
    print('The pool still exists.');
  } on XrplConnectionException {
    print('The pool no longer exists: it was deleted with its last LP.');
  }

  await connection.disconnect();
}

// Reads the XRP/TST pool and prints its current trading fee, so each
// vote's effect is visible.
Future<void> _printTradingFee(
  XrplConnection connection,
  XrplWallet issuer,
  String label,
) async {
  final info = await ammInfo(
    connection,
    asset: const XrplAsset.xrp(),
    asset2: XrplAsset.issued(
      currency: 'TST',
      issuer: issuer.classicAddress,
    ),
    ledgerIndex: 'validated',
  );
  print('$label: trading fee ${info.tradingFee} (1/100000 units)');
}

Future<void> voteAmmExample() async {
  final connection = XrplConnection(XrplEndpoint.testnet);
  await connection.connect();

  final accounts = await _prepareTokenHolder(connection);
  final holder = accounts.holder;

  // Start from a real pool: 5 XRP and 50 TST, at a 0.5% trading fee.
  // The holder is its only liquidity provider.
  await sendTransaction(
    connection,
    XrplAmmCreate(
      account: holder.classicAddress,
      amount: const XrplCurrencyAmount.xrp('5000000'),
      amount2: XrplCurrencyAmount.issued(
        currency: 'TST',
        issuer: accounts.issuer.classicAddress,
        value: '50',
      ),
      tradingFee: 500,
    ),
    holder,
  );

  // The pool is identified by its two assets, in any order.
  const xrp = XrplAsset.xrp();
  final tst = XrplAsset.issued(
    currency: 'TST',
    issuer: accounts.issuer.classicAddress,
  );

  await _printTradingFee(connection, accounts.issuer, 'Before');

  // ---- Vote 1: the only provider ----
  // The holder owns every LP token, so its vote alone decides the
  // pool's fee. TradingFee is in units of 1/100000, so 300 = 0.3%
  // (maximum 1000).
  final first = await sendTransaction(
    connection,
    XrplAmmVote(
      account: holder.classicAddress,
      asset: xrp,
      asset2: tst,
      tradingFee: 300,
    ),
    holder,
  );
  final firstMeta = first['meta'] as Map<String, dynamic>;
  print('Holder votes 300: ${firstMeta['TransactionResult']}');
  // Like AMMDeposit and AMMWithdraw, AMMVote pays the normal cost.
  print('Fee paid (drops): ${first['Fee']}');
  await _printTradingFee(connection, accounts.issuer, 'After holder vote');

  // ---- Vote 2: a second provider ----
  // Only liquidity providers can vote, so the second account first adds
  // 1 XRP to the pool (see XrplAmmDeposit) and then votes for the
  // maximum fee. Its vote weighs as much as its share of the LP tokens,
  // so the pool's fee moves towards 1000 only as far as that share
  // allows.
  final provider = await fundTestWallet(connection);
  print('Second provider: ${provider.classicAddress}');
  await sendTransaction(
    connection,
    XrplAmmDeposit.singleAsset(
      account: provider.classicAddress,
      asset: xrp,
      asset2: tst,
      amount: const XrplCurrencyAmount.xrp('1000000'),
    ),
    provider,
  );
  final second = await sendTransaction(
    connection,
    XrplAmmVote(
      account: provider.classicAddress,
      asset: xrp,
      asset2: tst,
      tradingFee: 1000,
    ),
    provider,
  );
  final secondMeta = second['meta'] as Map<String, dynamic>;
  print('Second provider votes 1000: ${secondMeta['TransactionResult']}');
  await _printTradingFee(connection, accounts.issuer, 'After second vote');

  await connection.disconnect();
}

// Reads the XRP/TST pool and prints who holds its auction slot, so each
// bid's effect is visible. Returns the info so the caller can reuse it.
Future<XrplAmmInfo> _printAuctionSlot(
  XrplConnection connection,
  XrplWallet issuer,
  String label,
) async {
  final info = await ammInfo(
    connection,
    asset: const XrplAsset.xrp(),
    asset2: XrplAsset.issued(
      currency: 'TST',
      issuer: issuer.classicAddress,
    ),
    ledgerIndex: 'validated',
  );
  print('$label LP tokens in circulation: ${info.lpToken.value}');

  final slot = info.auctionSlot;
  if (slot == null) {
    print('$label auction slot: none');
    return info;
  }
  print('$label slot holder: ${slot.account}');
  print('$label slot price: ${slot.price.value} LP tokens');
  print(
    '$label discounted fee: ${slot.discountedFee} '
    '(normal fee: ${info.tradingFee})',
  );
  print('$label authorized accounts: ${slot.authAccounts}');
  return info;
}

Future<void> bidAmmExample() async {
  final connection = XrplConnection(XrplEndpoint.testnet);
  await connection.connect();

  final accounts = await _prepareTokenHolder(connection);
  final holder = accounts.holder;

  // Start from a real pool: 5 XRP and 50 TST, at a 0.5% trading fee.
  // The holder is its only liquidity provider, so it owns every LP
  // token.
  await sendTransaction(
    connection,
    XrplAmmCreate(
      account: holder.classicAddress,
      amount: const XrplCurrencyAmount.xrp('5000000'),
      amount2: XrplCurrencyAmount.issued(
        currency: 'TST',
        issuer: accounts.issuer.classicAddress,
        value: '50',
      ),
      tradingFee: 500,
    ),
    holder,
  );

  // The pool is identified by its two assets, in any order.
  const xrp = XrplAsset.xrp();
  final tst = XrplAsset.issued(
    currency: 'TST',
    issuer: accounts.issuer.classicAddress,
  );

  final before = await _printAuctionSlot(
    connection,
    accounts.issuer,
    'Before any bid',
  );

  // ---- Bid 1: the minimum price, with an authorized account ----
  // With no bidMin and no bidMax, the holder pays the minimum needed to
  // win the slot. The authorized account must exist in the ledger, and
  // it cannot be the bidder itself. It also trades at the discounted
  // fee.
  final authorized = await fundTestWallet(connection);
  print('Authorized account: ${authorized.classicAddress}');
  final first = await sendTransaction(
    connection,
    XrplAmmBid(
      account: holder.classicAddress,
      asset: xrp,
      asset2: tst,
      authAccounts: [authorized.classicAddress],
    ),
    holder,
  );
  final firstMeta = first['meta'] as Map<String, dynamic>;
  print('Holder bids: ${firstMeta['TransactionResult']}');
  // Like AMMDeposit, AMMWithdraw and AMMVote, AMMBid pays the normal
  // transaction cost.
  print('Fee paid (drops): ${first['Fee']}');
  await _printAuctionSlot(connection, accounts.issuer, 'After holder bid');

  // ---- Bid 2: a second provider outbids the first ----
  // Only liquidity providers can bid, so the second account first adds
  // 1 XRP to the pool (see XrplAmmDeposit). Its bid must beat the
  // current one, and bidMax caps what it is willing to pay. The LP token
  // currency and issuer come from ammInfo, never from hand-built codes.
  // The holder is refunded part of its bid, based on how much of the
  // 24 hours is left.
  final provider = await fundTestWallet(connection);
  print('Second provider: ${provider.classicAddress}');
  await sendTransaction(
    connection,
    XrplAmmDeposit.singleAsset(
      account: provider.classicAddress,
      asset: xrp,
      asset2: tst,
      amount: const XrplCurrencyAmount.xrp('1000000'),
    ),
    provider,
  );
  final lp = before.lpToken;
  final second = await sendTransaction(
    connection,
    XrplAmmBid(
      account: provider.classicAddress,
      asset: xrp,
      asset2: tst,
      bidMax: XrplCurrencyAmount.issued(
        currency: lp.currency!,
        issuer: lp.issuer!,
        value: '100',
      ),
    ),
    provider,
  );
  final secondMeta = second['meta'] as Map<String, dynamic>;
  print('Second provider bids: ${secondMeta['TransactionResult']}');
  await _printAuctionSlot(connection, accounts.issuer, 'After second bid');

  await connection.disconnect();
}
