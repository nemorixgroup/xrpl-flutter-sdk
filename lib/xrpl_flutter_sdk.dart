// ignore_for_file: document_ignores, directives_ordering

/// The first native Flutter/Dart SDK for the XRP Ledger (XRPL).
///
/// Pure Dart, no platform channels.
library;

// ------------------------------------------
// Phase 1: Cryptographic fundamentals.
// ------------------------------------------

// Phase 1: Cryptographic fundamentals.
export 'src/codec/xrpl_base58.dart';
export 'src/crypto/xrpl_entropy.dart';
export 'src/crypto/xrpl_hash.dart';
export 'src/crypto/xrpl_key_algorithm.dart';
export 'src/crypto/xrpl_secp256k1.dart';
export 'src/crypto/xrpl_seed.dart';
export 'src/crypto/xrpl_ed25519.dart';
export 'src/exceptions/xrpl_crypto_exception.dart';
export 'src/wallet/xrpl_wallet.dart';

// Phase 2: Addresses.
export 'src/address/xrpl_classic_address.dart';
export 'src/address/xrpl_network.dart';
export 'src/address/xrpl_x_address.dart';

// Phase 3: Connection layer.
export 'src/connection/xrpl_endpoint.dart';
export 'src/connection/xrpl_connection.dart';
export 'src/exceptions/xrpl_connection_exception.dart';
export 'src/connection/xrpl_queries.dart';
export 'src/connection/xrpl_subscriptions.dart';

// Phase 4: Core transactions.
export 'src/transactions/xrpl_transaction.dart';
export 'src/transactions/models/xrpl_payment.dart';
export 'src/transactions/models/xrpl_trust_set.dart';
export 'src/transactions/xrpl_fee_strategy.dart';
export 'src/transactions/xrpl_autofill.dart';
