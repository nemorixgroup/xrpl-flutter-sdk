import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

// Shared setup for the AMM integration tests against the real public
// Testnet server.
//
// Creating or using a real pool needs more setup than any other
// transaction in this SDK:
//   1. The token issuer must have Default Ripple enabled, otherwise
//      the server rejects the pool with terNO_RIPPLE. That is an
//      AccountSet with SetFlag 8 (asfDefaultRipple). The SDK has no
//      public AccountSet model yet (Phase 8), so this file keeps a
//      small private, test-only transaction for it.
//   2. The pool creator must HOLD the token (an issuer cannot hold its
//      own token), so two wallets are needed: an issuer and a holder.
//   3. The holder opens a trust line (XrplTrustSet) and receives the
//      token by crossing an offer the issuer posts (XrplOfferCreate),
//      since XrplPayment is XRP-only in this SDK.
//
// This file is not a test itself (its name does not end in _test), so
// flutter test does not run it directly; the AMM integration tests
// import it.

/// The currency code of the token every AMM test pool uses.
const xrplAmmTestCurrency = 'TST';

const _asfDefaultRipple = 8;

// Test-only AccountSet that sets a single account flag.
class _AccountSetFlag implements XrplTransaction {
  const _AccountSetFlag({
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
  _AccountSetFlag copyWith({
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  }) {
    return _AccountSetFlag(
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

/// The two funded wallets of an AMM test: the token [issuer], and the
/// [holder] that owns the token and uses the pool.
class XrplAmmTestAccounts {
  /// Creates the pair from an already prepared [issuer] and [holder].
  const XrplAmmTestAccounts({required this.issuer, required this.holder});

  /// The wallet that issues the test token.
  final XrplWallet issuer;

  /// The wallet that holds the token and creates or uses the pool.
  final XrplWallet holder;

  /// The XRP side of the pool.
  XrplAsset get xrpAsset => const XrplAsset.xrp();

  /// The token side of the pool.
  XrplAsset get tokenAsset => XrplAsset.issued(
        currency: xrplAmmTestCurrency,
        issuer: issuer.classicAddress,
      );

  /// An amount of the test token.
  XrplCurrencyAmount tokenAmount(String value) {
    return XrplCurrencyAmount.issued(
      currency: xrplAmmTestCurrency,
      issuer: issuer.classicAddress,
      value: value,
    );
  }
}

/// Submits [transaction] with [wallet] and expects it to be validated
/// with `tesSUCCESS`. Returns the full result.
Future<Map<String, dynamic>> submitExpectingSuccess(
  XrplConnection connection,
  XrplTransaction transaction,
  XrplWallet wallet,
) async {
  final result = await sendTransaction(connection, transaction, wallet);
  expect(result['validated'], isTrue);
  expect(transactionResultOf(result), 'tesSUCCESS');
  return result;
}

/// The `TransactionResult` code from a validated transaction result.
String transactionResultOf(Map<String, dynamic> result) {
  return (result['meta'] as Map<String, dynamic>)['TransactionResult']
      as String;
}

/// Funds an issuer and a holder, and leaves the holder owning 100
/// units of the test token, ready to create or use a pool.
Future<XrplAmmTestAccounts> prepareTokenHolder(
  XrplConnection connection,
) async {
  final issuer = await fundTestWallet(connection);
  final holder = await fundTestWallet(connection);
  final accounts = XrplAmmTestAccounts(issuer: issuer, holder: holder);

  // 1. The issuer enables Default Ripple.
  await submitExpectingSuccess(
    connection,
    _AccountSetFlag(
      account: issuer.classicAddress,
      setFlag: _asfDefaultRipple,
    ),
    issuer,
  );

  // 2. The holder opens a trust line for the token.
  await submitExpectingSuccess(
    connection,
    XrplTrustSet(
      account: holder.classicAddress,
      currency: xrplAmmTestCurrency,
      issuer: issuer.classicAddress,
      limitValue: '1000',
    ),
    holder,
  );

  // 3. The issuer sells 100 tokens for 10 XRP, and the holder takes it.
  await submitExpectingSuccess(
    connection,
    XrplOfferCreate(
      account: issuer.classicAddress,
      takerGets: accounts.tokenAmount('100'),
      takerPays: const XrplCurrencyAmount.xrp('10000000'),
    ),
    issuer,
  );
  await submitExpectingSuccess(
    connection,
    XrplOfferCreate(
      account: holder.classicAddress,
      takerGets: const XrplCurrencyAmount.xrp('10000000'),
      takerPays: accounts.tokenAmount('100'),
    ),
    holder,
  );

  return accounts;
}

/// Does [prepareTokenHolder], then creates a real pool with the
/// holder: 5 XRP and 50 of the test token, at a 0.5% trading fee. The
/// holder is left with the pool's LP tokens and with 50 tokens.
Future<XrplAmmTestAccounts> createTestPool(XrplConnection connection) async {
  final accounts = await prepareTokenHolder(connection);

  await submitExpectingSuccess(
    connection,
    XrplAmmCreate(
      account: accounts.holder.classicAddress,
      amount: const XrplCurrencyAmount.xrp('5000000'),
      amount2: accounts.tokenAmount('50'),
      tradingFee: 500,
    ),
    accounts.holder,
  );

  return accounts;
}
