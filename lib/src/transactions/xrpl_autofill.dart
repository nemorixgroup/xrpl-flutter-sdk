import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/connection/xrpl_queries.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_fee_strategy.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_transaction.dart';

/// Fills in [transaction]'s `sequence`, `fee`, and
/// `lastLedgerSequence` automatically, using [connection] to look up
/// the current, correct values - matching the behavior of the
/// official `xrpl.js` library's `autofill` method.
///
/// Reuses `accountInfo` (for the account's current `Sequence`) and
/// `fee` (for the current transaction cost and ledger index),
/// instead of duplicating either lookup.
///
/// [feeStrategy] selects which of the `fee` command's several
/// reported values to use; defaults to [XrplFeeStrategy.openLedger],
/// the official recommendation for reliable, prompt inclusion.
///
/// `lastLedgerSequence` is set to the current ledger index plus 4,
/// the minimum official recommendation from "Reliable Transaction
/// Submission" for automated processes.
///
/// Any field already set on [transaction] is left as-is - `autofill`
/// only fills in what's missing, the same behavior `xrpl.js`
/// documents for its own `autofill`.
///
/// Throws an `XrplConnectionException` (via `accountInfo`/`fee`) if
/// not connected, either request times out, or the server returns an
/// error.
///
/// Example:
/// ```dart
/// final payment = XrplPayment(
///   account: wallet.classicAddress,
///   destination: 'rSomeRecipientAddress...',
///   amountDrops: '10000000',
/// );
/// final ready = await autofill(connection, payment);
/// print(ready.sequence); // no longer null
/// ```
///
/// See:
/// https://xrpl.org/docs/concepts/transactions/reliable-transaction-submission
Future<T> autofill<T extends XrplTransaction>(
  XrplConnection connection,
  T transaction, {
  XrplFeeStrategy feeStrategy = XrplFeeStrategy.openLedger,
}) async {
  // Look up the account's current sequence number, unless the caller
  // already provided one explicitly.
  final sequence = transaction.sequence ??
      await _lookUpSequence(connection, transaction.account);

  // Look up the fee and current ledger index together - the fee
  // command's response conveniently includes both in one call.
  final String feeValue;
  final int? lastLedgerSequence;
  if (transaction.fee != null && transaction.lastLedgerSequence != null) {
    feeValue = transaction.fee!;
    lastLedgerSequence = transaction.lastLedgerSequence;
  } else {
    final feeInfo = await fee(connection);
    final drops = feeInfo['drops'] as Map<String, dynamic>;
    feeValue = transaction.fee ?? _feeFor(feeStrategy, drops);
    lastLedgerSequence = transaction.lastLedgerSequence ??
        (feeInfo['ledger_current_index'] as int) + 4;
  }

  // The cast back to T is safe: every concrete XrplTransaction
  // subtype overrides copyWith to return its own type (for example,
  // XrplPayment.copyWith returns XrplPayment), so the runtime type
  // here always matches T - the interface just can't express that
  // relationship statically.
  return transaction.copyWith(
    sequence: sequence,
    fee: feeValue,
    lastLedgerSequence: lastLedgerSequence,
  ) as T;
}

Future<int> _lookUpSequence(XrplConnection connection, String account) async {
  final accountData = await accountInfo(connection, account);
  return accountData['Sequence'] as int;
}

String _feeFor(XrplFeeStrategy strategy, Map<String, dynamic> drops) {
  switch (strategy) {
    case XrplFeeStrategy.openLedger:
      return drops['open_ledger_fee'] as String;
    case XrplFeeStrategy.minimum:
      return drops['minimum_fee'] as String;
    case XrplFeeStrategy.median:
      return drops['median_fee'] as String;
    case XrplFeeStrategy.base:
      return drops['base_fee'] as String;
  }
}
