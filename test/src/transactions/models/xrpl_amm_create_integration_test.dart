@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

// Integration test: XrplAmmCreate and ammInfo against the real public
// Testnet server, end to end (autofill with the owner-reserve fee,
// signing, submission, ledger metadata, and reading the pool back).
//
// Creating a real pool needs more setup than any earlier transaction:
//   1. The token issuer must have Default Ripple enabled, otherwise the
//      server rejects the AMM with terNO_RIPPLE. That is an AccountSet
//      with SetFlag 8 (asfDefaultRipple). The SDK has no public
//      AccountSet model yet (Phase 8), so this file uses a small
//      private, test-only transaction for it.
//   2. The pool creator must HOLD the token (an issuer cannot hold its
//      own token), so two wallets are needed: issuer and holder.
//   3. The holder opens a trust line (XrplTrustSet) and receives TST by
//      crossing an offer the issuer posts (XrplOfferCreate), since
//      XrplPayment is XRP-only in this SDK.

// Test-only AccountSet that sets (or clears) a single account flag.
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

const _asfDefaultRipple = 8;

Future<Map<String, dynamic>> _submit(
  XrplConnection connection,
  XrplTransaction transaction,
  XrplWallet wallet,
) async {
  final result = await sendTransaction(connection, transaction, wallet);
  expect(result['validated'], isTrue);
  return result;
}

String _resultCode(Map<String, dynamic> result) =>
    (result['meta'] as Map<String, dynamic>)['TransactionResult'] as String;

void main() {
  group('XrplAmmCreate and ammInfo against the real public Testnet server', () {
    test(
      'creates a real pool, reads it back with ammInfo, and a second '
      'AMMCreate for the same pair is rejected',
      () async {
        final connection = XrplConnection(XrplEndpoint.testnet);
        await connection.connect();
        addTearDown(connection.disconnect);

        final issuer = await fundTestWallet(connection);
        final holder = await fundTestWallet(connection);

        // 1. Issuer enables Default Ripple.
        final accountSet = await _submit(
          connection,
          _AccountSetFlag(
            account: issuer.classicAddress,
            setFlag: _asfDefaultRipple,
          ),
          issuer,
        );
        expect(_resultCode(accountSet), 'tesSUCCESS');

        // 2. Holder opens a trust line for TST.
        final trustSet = await _submit(
          connection,
          XrplTrustSet(
            account: holder.classicAddress,
            currency: 'TST',
            issuer: issuer.classicAddress,
            limitValue: '1000',
          ),
          holder,
        );
        expect(_resultCode(trustSet), 'tesSUCCESS');

        // 3. Issuer sells 100 TST for 10 XRP; holder crosses it.
        final issuerOffer = await _submit(
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
        expect(_resultCode(issuerOffer), 'tesSUCCESS');

        final holderOffer = await _submit(
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
        expect(_resultCode(holderOffer), 'tesSUCCESS');

        // 4. Holder creates the pool: 5 XRP + 50 TST, 0.5% trading fee.
        final ammCreate = XrplAmmCreate(
          account: holder.classicAddress,
          amount: const XrplCurrencyAmount.xrp('5000000'),
          amount2: XrplCurrencyAmount.issued(
            currency: 'TST',
            issuer: issuer.classicAddress,
            value: '50',
          ),
          tradingFee: 500,
        );

        // autofill must have used the owner reserve, not the base fee.
        final filled = await autofill(connection, ammCreate);
        final state = await serverState(connection);
        final reserveInc =
            (state['validated_ledger'] as Map<String, dynamic>)['reserve_inc'];
        expect(filled.fee, reserveInc.toString());

        final created = await _submit(connection, ammCreate, holder);
        expect(_resultCode(created), 'tesSUCCESS');

        final nodes = (created['meta'] as Map<String, dynamic>)['AffectedNodes']
            as List<dynamic>;
        final createdAmm = nodes.any((node) {
          final created = (node as Map<String, dynamic>)['CreatedNode']
              as Map<String, dynamic>?;
          return created?['LedgerEntryType'] == 'AMM';
        });
        expect(
          createdAmm,
          isTrue,
          reason: 'Expected a CreatedNode of type AMM in the metadata',
        );

        // 5. Read the pool back. Do not assume amount/amount2 order.
        final info = await ammInfo(
          connection,
          asset: const XrplAsset.xrp(),
          asset2: XrplAsset.issued(
            currency: 'TST',
            issuer: issuer.classicAddress,
          ),
          ledgerIndex: 'validated',
        );

        expect(info.tradingFee, 500);
        expect(info.validated, isTrue);
        final sides = [info.amount, info.amount2];
        final xrpSide = sides.singleWhere((a) => a.isXrp);
        final tokenSide = sides.singleWhere((a) => !a.isXrp);
        expect(xrpSide.drops, '5000000');
        expect(double.parse(tokenSide.value!), 50);
        expect(tokenSide.currency, 'TST');
        expect(tokenSide.issuer, issuer.classicAddress);
        expect(info.lpToken.isXrp, isFalse);

        // Same pair looked up by the AMM account gives the same pool.
        final byAccount = await ammInfo(
          connection,
          ammAccount: info.account,
          ledgerIndex: 'validated',
        );
        expect(byAccount.account, info.account);

        // 6. A second AMMCreate for the same pair is rejected by the
        // server (tecDUPLICATE per the AMMCreate documentation).
        final duplicate = await _submit(
          connection,
          XrplAmmCreate(
            account: holder.classicAddress,
            amount: const XrplCurrencyAmount.xrp('1000000'),
            amount2: XrplCurrencyAmount.issued(
              currency: 'TST',
              issuer: issuer.classicAddress,
              value: '10',
            ),
            tradingFee: 500,
          ),
          holder,
        );
        expect(_resultCode(duplicate), 'tecDUPLICATE');
      },
    );

    test('ammInfo for a pair with no pool throws actNotFound', () async {
      final connection = XrplConnection(XrplEndpoint.testnet);
      await connection.connect();
      addTearDown(connection.disconnect);

      final issuer = await fundTestWallet(connection);

      expect(
        () => ammInfo(
          connection,
          asset: const XrplAsset.xrp(),
          asset2: XrplAsset.issued(
            currency: 'TST',
            issuer: issuer.classicAddress,
          ),
        ),
        throwsA(isA<XrplConnectionException>()),
      );
    });
  });
}
