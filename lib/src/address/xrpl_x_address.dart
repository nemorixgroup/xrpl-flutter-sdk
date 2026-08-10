import 'dart:typed_data';

import 'package:xrpl_flutter_sdk/src/address/xrpl_classic_address.dart';
import 'package:xrpl_flutter_sdk/src/address/xrpl_network.dart';
import 'package:xrpl_flutter_sdk/src/codec/xrpl_base58.dart';
import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';

/// Derives an XRPL X-address from a public key, a network, and an
/// optional destination tag.
///
/// A classic address ("r...") only identifies an *account*. Many
/// real-world destinations (exchanges, payment processors) share one
/// account across many users, and distinguish them with a separate
/// "destination tag" number that has to be supplied alongside the
/// address on every transaction. If a sender forgets that tag, funds
/// can arrive at the right account but become unattributable to the
/// intended recipient.
///
/// X-addresses solve this by encoding the account, the tag (if any),
/// and which network the address is meant for into a single base58
/// string, so there's nothing separate left to forget.
///
/// See: https://xrpl.org/docs/concepts/accounts/addresses#x-address-format
class XrplXAddress {
  const XrplXAddress._();

  /// The two-byte type prefix for a Mainnet X-address (`0x05 0x44`),
  /// producing addresses that start with `X`.
  static const List<int> mainnetPrefix = [0x05, 0x44];

  /// The two-byte type prefix for a Testnet X-address (`0x04 0x93`),
  /// producing addresses that start with `T`.
  static const List<int> testnetPrefix = [0x04, 0x93];

  /// The largest destination tag value the 32-bit tag field can hold
  /// (`0xFFFFFFFF`). XRPL's X-address format reserves a flag value
  /// for 64-bit tags, but no client library (including the official
  /// `ripple-address-codec` reference) implements it, so this SDK
  /// does not accept tags above this limit either.
  static const int maxTagValue = 4294967295;

  /// Derives the X-address for [publicKey] on the given [network],
  /// optionally embedding a destination [tag].
  ///
  /// Throws an [XrplCryptoException] if [publicKey] is not 33 bytes
  /// (via [XrplClassicAddress.accountIdFromPublicKey]), or if [tag]
  /// is negative or exceeds [maxTagValue].
  ///
  /// Example:
  /// ```dart
  /// final xAddress = XrplXAddress.deriveFrom(
  ///   wallet.publicKeyBytes,
  ///   network: XrplNetwork.mainnet,
  ///   tag: 12345,
  /// );
  /// ```
  static String deriveFrom(
    Uint8List publicKey, {
    required XrplNetwork network,
    int? tag,
  }) {
    // Reuse the same Account ID derivation as classic addresses -
    // an X-address encodes the same account, just with more context.
    final accountId = XrplClassicAddress.accountIdFromPublicKey(publicKey);

    if (tag != null && (tag < 0 || tag > maxTagValue)) {
      throw XrplCryptoException(
        'tag must be between 0 and $maxTagValue, got $tag',
      );
    }

    // flag: 0 means "no tag", 1 means "this address carries a 32-bit
    // tag". A missing tag still reserves the tag bytes as zeros.
    final flag = tag == null ? 0x00 : 0x01;
    final tagValue = tag ?? 0;

    // Per the official spec, the tag is little-endian - the reverse
    // byte order from everything else built so far in this SDK
    // (seeds, keys), which are big-endian.
    final tagBytes = Uint8List(4)
      ..buffer.asByteData().setUint32(0, tagValue, Endian.little);

    final networkPrefix =
        network == XrplNetwork.mainnet ? mainnetPrefix : testnetPrefix;

    final payload = Uint8List.fromList([
      ...networkPrefix,
      ...accountId,
      flag,
      ...tagBytes,
      ...List.filled(4, 0), // reserved for a future 64-bit tag
    ]);

    return XrplBase58.encodeWithChecksum(payload);
  }
}
