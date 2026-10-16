// Phase 5 - 0.4.3-dev: AMMCreate & amm_info
//
// Demonstrates XRPL's native Automated Market Maker: creating a
// liquidity pool for an asset pair with XrplAmmCreate, then reading
// it back with ammInfo. Both use the same build -> autofill -> sign
// -> submitAndWait pipeline used throughout Phases 4 and 5.
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
// reserve_inc), so there is nothing to configure here.
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
