import 'package:xrpl_flutter_sdk/src/connection/xrpl_connection.dart';
import 'package:xrpl_flutter_sdk/src/transactions/models/xrpl_payment.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_fee_strategy.dart';
import 'package:xrpl_flutter_sdk/src/transactions/xrpl_send_transaction.dart';
import 'package:xrpl_flutter_sdk/src/wallet/xrpl_wallet.dart';

/// Sends XRP from [senderWallet] to [destinationAddress], in one call
/// - the simplest possible way to make a payment with this SDK.
///
/// Why this exists: most callers sending a simple XRP payment don't
/// need to know `XrplPayment` exists at all. This builds it
/// internally and calls [sendTransaction], so "send X XRP to this
/// address" is the entire mental model required.
///
/// [senderWallet] must be a full wallet (it holds the private key
/// needed to sign the transaction). [destinationAddress] is only the
/// recipient's public classic address, as a string - never a private
/// key, since sending funds never requires access to the recipient's
/// keys, only their address.
///
/// [amountDrops] is the amount to send, in drops (1 XRP = 1,000,000
/// drops). [destinationTag] is optional, for destinations that share
/// one account across many recipients (for example, an exchange).
///
/// For anything beyond a simple XRP payment (issued currencies, other
/// transaction types), build an `XrplPayment`/`XrplTrustSet` directly
/// and use [sendTransaction] instead.
///
/// Throws whatever [sendTransaction] throws.
///
/// Example:
/// ```dart
/// final result = await sendPayment(
///   connection,
///   senderWallet: myWallet,
///   destinationAddress: 'rSomeRecipientAddress...',
///   amountDrops: '10000000', // 10 XRP
/// );
/// print(result['meta']['TransactionResult']); // e.g. "tesSUCCESS"
/// ```
Future<Map<String, dynamic>> sendPayment(
  XrplConnection connection, {
  required XrplWallet senderWallet,
  required String destinationAddress,
  required String amountDrops,
  int? destinationTag,
  XrplFeeStrategy feeStrategy = XrplFeeStrategy.openLedger,
}) async {
  final payment = XrplPayment(
    account: senderWallet.classicAddress,
    destination: destinationAddress,
    amountDrops: amountDrops,
    destinationTag: destinationTag,
  );
  return sendTransaction(
    connection,
    payment,
    senderWallet,
    feeStrategy: feeStrategy,
  );
}
