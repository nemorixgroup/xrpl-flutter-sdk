import 'package:meta/meta.dart';

/// One of the two assets of an AMM pool: XRP, or an issued token.
///
/// Unlike `XrplCurrencyAmount`, an asset carries no value. It only
/// identifies *which* currency is meant, in the
/// `{"currency": ..., "issuer": ...}` shape the XRPL APIs use for
/// `asset` and `asset2` (for example in the `amm_info` request). XRP
/// has no issuer, so its JSON form is just `{"currency": "XRP"}`.
///
/// Use [XrplAsset.xrp] for XRP and [XrplAsset.issued] for a token.
/// [XrplAsset.issued] throws an [ArgumentError] when [currency] or
/// [issuer] is empty, or when [currency] is `'XRP'`, since XRP can
/// never be an issued token.
///
/// Example:
/// ```dart
/// const xrp = XrplAsset.xrp();
/// final tst = XrplAsset.issued(
///   currency: 'TST',
///   issuer: 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd',
/// );
///
/// print(xrp.toJson()); // {currency: XRP}
/// print(tst.toJson()); // {currency: TST, issuer: rP9j...}
/// ```
///
/// See:
/// https://xrpl.org/docs/references/http-websocket-apis/public-api-methods/path-and-order-book-methods/amm_info
@immutable
class XrplAsset {
  const XrplAsset._({required this.currency, this.issuer});

  /// The XRP asset. XRP has no issuer.
  const XrplAsset.xrp() : this._(currency: 'XRP');

  /// An issued token identified by its [currency] code and [issuer]
  /// address.
  ///
  /// Throws an [ArgumentError] if [currency] or [issuer] is empty, or
  /// if [currency] is `'XRP'` (use [XrplAsset.xrp] for XRP).
  factory XrplAsset.issued({
    required String currency,
    required String issuer,
  }) {
    if (currency.isEmpty) {
      throw ArgumentError.value(currency, 'currency', 'must not be empty');
    }
    if (currency == 'XRP') {
      throw ArgumentError.value(
        currency,
        'currency',
        'an issued asset cannot use the currency "XRP"; use '
            'XrplAsset.xrp() instead',
      );
    }
    if (issuer.isEmpty) {
      throw ArgumentError.value(issuer, 'issuer', 'must not be empty');
    }
    return XrplAsset._(currency: currency, issuer: issuer);
  }

  /// The currency code.
  final String currency;

  /// The issuer address, or `null` for XRP.
  final String? issuer;

  /// Whether this asset is XRP.
  bool get isXrp => issuer == null;

  /// Converts this asset to the JSON shape used by the XRPL APIs,
  /// omitting [issuer] for XRP.
  Map<String, dynamic> toJson() {
    return {
      'currency': currency,
      if (issuer != null) 'issuer': issuer,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is XrplAsset &&
        other.currency == currency &&
        other.issuer == issuer;
  }

  @override
  int get hashCode => Object.hash(currency, issuer);

  @override
  String toString() => 'XrplAsset(${toJson()})';
}
