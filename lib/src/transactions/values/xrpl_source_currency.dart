import 'package:meta/meta.dart';

/// A single entry in `ripple_path_find`/`path_find`'s `source_currencies`
/// list: a currency the source account is willing to send, optionally
/// restricted to one issuer.
///
/// Per the official specification, [currency] is required and [issuer]
/// is optional (omit it to let the server consider any issuer of that
/// currency the source account holds). `source_currencies` itself
/// accepts at most 18 of these entries; that limit is enforced where the
/// list is used (`ripplePathFind`), not here, since a single entry has
/// no way to know how many siblings it has.
///
/// Example:
/// ```dart
/// final anyUsd = XrplSourceCurrency(currency: 'USD');
/// final gatewayUsd = XrplSourceCurrency(
///   currency: 'USD',
///   issuer: 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
/// );
/// ```
///
/// See:
/// https://xrpl.org/docs/references/http-websocket-apis/public-api-methods/path-and-order-book-methods/ripple_path_find
@immutable
class XrplSourceCurrency {
  /// Creates a source currency entry.
  const XrplSourceCurrency({required this.currency, this.issuer});

  /// The currency code this entry describes.
  final String currency;

  /// The issuer this entry is restricted to, or null to allow any
  /// issuer of [currency] the source account holds.
  final String? issuer;

  /// Returns a copy of this entry with the given fields replaced.
  XrplSourceCurrency copyWith({String? currency, String? issuer}) {
    return XrplSourceCurrency(
      currency: currency ?? this.currency,
      issuer: issuer ?? this.issuer,
    );
  }

  /// Converts this entry to the JSON shape used by the XRPL APIs,
  /// omitting [issuer] when it wasn't set.
  Map<String, dynamic> toJson() {
    return {'currency': currency, if (issuer != null) 'issuer': issuer};
  }

  @override
  bool operator ==(Object other) {
    return other is XrplSourceCurrency &&
        other.currency == currency &&
        other.issuer == issuer;
  }

  @override
  int get hashCode => Object.hash(currency, issuer);

  @override
  String toString() => 'XrplSourceCurrency(${toJson()})';
}
