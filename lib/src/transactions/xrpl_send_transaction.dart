import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_autofill.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_fee_strategy.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_signer.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_submit_and_wait.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_transaction.dart';
import 'package:xrpl_flutter_sdk/src/wallet/xrpl_wallet.dart';

/// Builds, signs, submits, and waits for confirmation of
/// [transaction] in one call - the full pipeline (`autofill`,
/// `sign`, `submitAndWait`) for any transaction type this SDK
/// supports.
///
/// Why this exists: sending a transaction is, in full generality,
/// several separate steps (autofill, sign, submit, wait for
/// confirmation) that must be called in the right order with the
/// right values passed between them. Most callers just want "send
/// this transaction and tell me if it worked" - this collapses that
/// into one call, while each individual step (`autofill`, `sign`,
/// `submitAndWait`) remains available separately for callers who
/// need to inspect or modify the transaction in between (for
/// example, reviewing the autofilled `Fee` before signing).
///
/// [feeStrategy] is passed through to `autofill`; see
/// [XrplFeeStrategy] for what each option means.
///
/// Throws whatever `autofill`, `sign`, or `submitAndWait` throw - see
/// each for its specific error conditions.
///
/// Example:
/// ```dart
/// final result = await sendTransaction(connection, payment, wallet);
/// print(result['meta']['TransactionResult']); // e.g. "tesSUCCESS"
/// ```
Future<Map<String, dynamic>> sendTransaction<T extends XrplTransaction>(
  XrplConnection connection,
  T transaction,
  XrplWallet wallet, {
  XrplFeeStrategy feeStrategy = XrplFeeStrategy.openLedger,
}) async {
  final filled = await autofill(
    connection,
    transaction,
    feeStrategy: feeStrategy,
  );
  final signed = await sign(filled.toJson(), wallet);
  return submitAndWait(connection, signed);
}
