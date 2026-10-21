import 'dart:typed_data';

import 'package:xrpl_flutter_sdk/src/exceptions/xrpl_crypto_exception.dart';
import 'package:xrpl_flutter_sdk/src/transactions/binary/xrpl_binary_primitives.dart';

/// Encoders for XRPL's `Amount` binary type, in both forms this SDK
/// needs: a plain XRP amount (for `XrplPayment.amountDrops`), and an
/// issued-currency amount (for `XrplTrustSet`'s `LimitAmount`). It
/// also encodes the `Issue` type (an asset with no quantity), used by
/// `AMMDeposit`'s `Asset` and `Asset2`.
///
/// Both amount encoders were verified against an official worked
/// example (an `OfferCreate` transaction's published JSON and binary),
/// which happens to include one of each form (`TakerGets` as XRP,
/// `TakerPays` as an issued currency) - see
/// `docs-sdk/phase-4/signing/` for the full verification. The `Issue`
/// encoder was verified byte-for-byte against the official `xrpl-py`
/// binary codec.
///
/// See: https://xrpl.org/docs/references/protocol/binary-format#amount-fields
class XrplAmountSerializer {
  const XrplAmountSerializer._();

  /// The number of significant digits an issued-currency amount's
  /// mantissa is normalized to (the official range is `10^15` to
  /// `10^16 - 1`, which is 16 digits).
  static const int _mantissaDigits = 16;

  /// The bias added to an issued-currency amount's exponent before
  /// it's stored (so the stored, unsigned value can represent
  /// negative exponents).
  static const int _exponentBias = 97;

  /// Encodes a plain XRP amount, in [drops] (a decimal string of
  /// whole drops, no other currency): exactly 8 bytes, with the two
  /// most significant bits set to `01` (not an issued currency; a
  /// positive amount - XRP amounts in this position are always
  /// non-negative), followed by the drops value in the remaining 62
  /// bits.
  ///
  /// Throws an [XrplCryptoException] if [drops] isn't a valid
  /// non-negative integer, or exceeds what 62 bits can hold.
  static Uint8List encodeXrpAmount(String drops) {
    final BigInt value;
    try {
      value = BigInt.parse(drops);
    } on FormatException catch (_) {
      throw XrplCryptoException('drops must be a whole number, got "$drops"');
    }

    if (value < BigInt.zero) {
      throw XrplCryptoException('drops must not be negative, got "$drops"');
    }

    // 0x4000000000000000 sets bit 62 (the "positive XRP" marker) with
    // bit 63 left clear (meaning "this is XRP, not an issued
    // currency") - confirmed against the official TakerGets example.
    final flagged = BigInt.parse('4000000000000000', radix: 16) + value;

    if (flagged.bitLength > 64) {
      throw XrplCryptoException(
        'drops value "$drops" is too large to encode (exceeds 62 bits).',
      );
    }

    return _bigIntToBytes(flagged, 8);
  }

  /// Encodes an issued-currency amount: 48 bytes total - an 8-byte
  /// normalized value, a 20-byte [currency] code, and a 20-byte
  /// [issuer] Account ID.
  ///
  /// [currency] must be either a standard 3-letter code (for example
  /// `"USD"`) or a 40-character hex currency code. [value] is a
  /// decimal string, normalized to the official 16-significant-digit
  /// mantissa range before encoding.
  ///
  /// Throws an [XrplCryptoException] if [value] isn't a valid decimal
  /// number, if its magnitude is out of the representable exponent
  /// range, or if [issuer]'s checksum is invalid (via
  /// [XrplBinaryPrimitives.encodeAccountId]'s underlying decoding).
  static Uint8List encodeIssuedCurrencyAmount({
    required String currency,
    required String issuer,
    required String value,
  }) {
    final valueBytes = _encodeIssuedCurrencyValue(value);
    final currencyBytes = encodeCurrencyCode(currency);
    final issuerBytes = _encodeIssuerBytes(issuer);

    return Uint8List.fromList([
      ...valueBytes,
      ...currencyBytes,
      ...issuerBytes,
    ]);
  }

  /// Encodes an `Issue`: an asset identified without any quantity,
  /// as `AMMDeposit`'s `Asset` and `Asset2` fields use.
  ///
  /// XRP (a [currency] of `"XRP"` with no [issuer]) is exactly 20 zero
  /// bytes. A token is 40 bytes: the 20-byte [currency] code followed
  /// by the 20-byte [issuer] Account ID, with no length prefix. This
  /// was confirmed byte-for-byte against the official `xrpl-py`
  /// binary codec.
  ///
  /// Throws an [XrplCryptoException] if XRP is given an [issuer], if a
  /// token has no [issuer], or if [currency] or [issuer] is invalid.
  static Uint8List encodeIssue({required String currency, String? issuer}) {
    if (currency == 'XRP') {
      if (issuer != null) {
        throw XrplCryptoException(
          'XRP has no issuer, but an issuer was given ("$issuer")',
        );
      }
      return Uint8List(20);
    }

    if (issuer == null) {
      throw XrplCryptoException(
        'an issued currency needs an issuer, but none was given for '
        '"$currency"',
      );
    }

    return Uint8List.fromList([
      ...encodeCurrencyCode(currency),
      ..._encodeIssuerBytes(issuer),
    ]);
  }

  /// Encodes a [currency] code into its 20 bytes: either a standard
  /// 3-letter code (for example `"USD"`), or a raw 40-character hex
  /// code, such as the one XRPL assigns to an AMM's LP tokens.
  ///
  /// Throws an [XrplCryptoException] if [currency] is neither, if a
  /// 3-letter code has non-ASCII characters, or if a 40-character code
  /// is not valid hexadecimal.
  static Uint8List encodeCurrencyCode(String currency) {
    if (currency.length == 40) {
      if (!RegExp(r'^[0-9A-Fa-f]{40}$').hasMatch(currency)) {
        throw XrplCryptoException(
          'a 40-character currency code must be valid hexadecimal, '
          'got "$currency"',
        );
      }
      // Already a raw 160-bit hex currency code.
      return _hexToBytes(currency);
    }

    if (currency.length != 3) {
      throw XrplCryptoException(
        'currency must be a 3-letter code or a 40-character hex code, '
        'got "$currency" (${currency.length} characters)',
      );
    }

    final asciiBytes = currency.codeUnits;
    for (final unit in asciiBytes) {
      if (unit > 0x7F) {
        throw XrplCryptoException(
          'currency must contain only ASCII characters, got "$currency"',
        );
      }
    }

    // Standard format, confirmed against the official "USD" example:
    // 12 zero bytes, then the 3 ASCII letters, then 5 more zero bytes.
    return Uint8List.fromList([
      ...List.filled(12, 0),
      ...asciiBytes,
      ...List.filled(5, 0),
    ]);
  }

  /// The issuer here is embedded at a fixed 20 bytes with no length
  /// prefix of its own (unlike a standalone AccountID field) - strip
  /// the length-prefix byte that encodeAccountId adds for that
  /// separate use case.
  static Uint8List _encodeIssuerBytes(String issuer) {
    final accountIdWithPrefix = XrplBinaryPrimitives.encodeAccountId(issuer);
    return accountIdWithPrefix.sublist(1);
  }

  static Uint8List _encodeIssuedCurrencyValue(String value) {
    var raw = value;
    final negative = raw.startsWith('-');
    if (negative) raw = raw.substring(1);

    final parts = raw.split('.');
    if (parts.length > 2) {
      throw XrplCryptoException(
        'value must have at most one decimal point, got "$value"',
      );
    }
    final intPart = parts[0];
    final fracPart = parts.length > 1 ? parts[1] : '';

    final digitsOnly = RegExp(r'^[0-9]*$');
    if (!digitsOnly.hasMatch(intPart) ||
        !digitsOnly.hasMatch(fracPart) ||
        (intPart.isEmpty && fracPart.isEmpty)) {
      throw XrplCryptoException(
        'value must be a valid decimal number, got "$value"',
      );
    }

    var digits = intPart + fracPart;
    // Strip leading zeros so digit-count normalization below reflects
    // only significant digits.
    final leadingZerosStripped = digits.replaceFirst(RegExp('^0+'), '');
    var exponent = -fracPart.length;

    if (leadingZerosStripped.isEmpty) {
      // Zero has a special, fixed encoding: only the "not XRP" bit
      // set, everything else zero.
      return _bigIntToBytes(BigInt.parse('8000000000000000', radix: 16), 8);
    }
    digits = leadingZerosStripped;

    BigInt mantissa;
    if (digits.length < _mantissaDigits) {
      final pad = _mantissaDigits - digits.length;
      mantissa = BigInt.parse(digits + '0' * pad);
      exponent -= pad;
    } else if (digits.length > _mantissaDigits) {
      final cut = digits.length - _mantissaDigits;
      // Truncated, not rounded - this SDK's current use (TrustSet
      // limits) does not need sub-mantissa precision; rounding can
      // be added if a real need for more than 16 significant digits
      // of precision arises.
      mantissa = BigInt.parse(digits.substring(0, _mantissaDigits));
      exponent += cut;
    } else {
      mantissa = BigInt.parse(digits);
    }

    final exponentRaw = exponent + _exponentBias;
    if (exponentRaw < 0 || exponentRaw > 0xFF) {
      throw XrplCryptoException(
        'value "$value" has an exponent out of the representable range.',
      );
    }

    final notXrpBit = BigInt.one << 63;
    final signBit = negative ? BigInt.zero : (BigInt.one << 62);
    final exponentBits = BigInt.from(exponentRaw) << 54;

    final full = notXrpBit | signBit | exponentBits | mantissa;
    return _bigIntToBytes(full, 8);
  }

  static Uint8List _bigIntToBytes(BigInt value, int length) {
    final result = Uint8List(length);
    var remaining = value;
    for (var i = length - 1; i >= 0; i--) {
      result[i] = (remaining & BigInt.from(0xff)).toInt();
      remaining = remaining >> 8;
    }
    return result;
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}
