// Phase 5
//  - 0.4.3-dev: AMMCreate, amm_info.
//  - 0.4.4-dev: AMMDeposit.
//
// Demonstrates XRPL's native Automated Market Maker: creating a
// liquidity pool for an asset pair with XrplAmmCreate, reading it back
// with ammInfo, and adding liquidity to it with XrplAmmDeposit. All of
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
// reserve_inc), so there is nothing to configure here. AMMDeposit, in
// contrast, pays the normal transaction cost.
//
// Deposit note: XrplAmmDeposit has one named constructor per deposit
// mode (singleAsset, twoAsset, lpToken, oneAssetLpToken, limitLpToken,
// twoAssetIfEmpty), so an invalid mix of fields does not compile. The
// last mode only works on an EMPTY pool and is not shown here.
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
