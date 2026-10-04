import 'package:meta/meta.dart';

/// A single step in an XRP Ledger payment path.
///
/// A payment `Path` is a sequence of steps describing how value moves from
/// the sender to the recipient when a cross-currency payment can't be sent
/// directly (for example, USD -> EUR, or USD issued by one gateway -> USD
/// issued by another). Each step tells the server either "ripple through
/// this account" or "change currency/issuer here via the order book".
///
/// Per the official specification, a step may specify [account] alone, or
/// [currency] and/or [issuer] alone, but never [account] together with
/// [currency] or [issuer] in the same step. This class enforces that rule
/// at construction time with an [ArgumentError], since it's a rule any SDK
/// consumer can violate by passing the wrong combination of fields, not an
/// internal SDK invariant.
///
/// The official specification also marks the [currency] + [issuer]
/// combination as valid for non-XRP currencies only: XRP is the network's
/// native asset and has no issuer, so a step combining `currency: 'XRP'`
/// with a non-null [issuer] is rejected the same way, with its own
/// [ArgumentError].
///
/// The legacy `type`/`type_hex` fields from the official JSON format are
/// deliberately not modeled here: the official documentation marks them
/// deprecated, and they carry no information beyond which of
/// [account]/[currency]/[issuer] are present.
///
/// Example:
/// ```dart
/// // "Ripple through this intermediary account."
/// final step1 = XrplPathStep(account: 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe');
///
/// // "Change to USD issued by this gateway via the order book."
/// final step2 = XrplPathStep(
///   currency: 'USD',
///   issuer: 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B',
/// );
/// ```
///
/// See: https://xrpl.org/docs/concepts/tokens/fungible-tokens/paths
@immutable
class XrplPathStep {
  /// Creates a payment path step.
  ///
  /// Throws an [ArgumentError] if [account] is provided together with
  /// either [currency] or [issuer], since the official specification
  /// forbids that combination. Also throws an [ArgumentError] if
  /// [currency] is `'XRP'` and [issuer] is provided, since XRP has no
  /// issuer.
  XrplPathStep({this.account, this.currency, this.issuer}) {
    if (account != null && (currency != null || issuer != null)) {
      throw ArgumentError(
        'A PathStep with account must not also specify currency or '
        'issuer.',
      );
    }
    if (currency == 'XRP' && issuer != null) {
      throw ArgumentError(
        'A PathStep with currency "XRP" must not also specify issuer, '
        'since XRP has no issuer.',
      );
    }
  }

  /// The account to ripple through at this step, or null if this step
  /// instead describes a currency/issuer change.
  final String? account;

  /// The currency code to change to at this step via the order book, or
  /// null if this step doesn't change currency.
  final String? currency;

  /// The issuer to use for [currency] at this step, or null if this step
  /// doesn't specify one.
  final String? issuer;

  /// Returns a copy of this step with the given fields replaced.
  ///
  /// Still validates both the account/currency/issuer exclusion rule and
  /// the XRP/issuer exclusion rule, so `copyWith` can throw an
  /// [ArgumentError] the same way the constructor does.
  XrplPathStep copyWith({String? account, String? currency, String? issuer}) {
    return XrplPathStep(
      account: account ?? this.account,
      currency: currency ?? this.currency,
      issuer: issuer ?? this.issuer,
    );
  }

  /// Converts this step to the JSON shape used by the XRPL APIs, omitting
  /// any field that wasn't set.
  Map<String, dynamic> toJson() {
    return {
      if (account != null) 'account': account,
      if (currency != null) 'currency': currency,
      if (issuer != null) 'issuer': issuer,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is XrplPathStep &&
        other.account == account &&
        other.currency == currency &&
        other.issuer == issuer;
  }

  @override
  int get hashCode => Object.hash(account, currency, issuer);

  @override
  String toString() => 'XrplPathStep(${toJson()})';
}

/// A single candidate payment path: an ordered sequence of [XrplPathStep].
///
/// A `Path` describes one complete route value could take from sender to
/// recipient. The `Paths` field on a `Payment` transaction (a `PathSet`) is
/// a list of these, one per candidate route the server should consider.
///
/// This is a thin wrapper around `List<XrplPathStep>` rather than a plain
/// type alias, so it has a clear, documented place in the SDK's public API
/// and a natural spot for `toJson()`.
///
/// The constructor is marked `const` to satisfy this project's lint rules
/// for `@immutable` classes, but in practice an `XrplPath` is rarely built
/// as a true compile-time constant: since every [XrplPathStep] it holds is
/// validated at runtime (see [XrplPathStep]'s [ArgumentError]), the steps
/// list itself is almost never a compile-time constant.
///
/// Example:
/// ```dart
/// final path = XrplPath([
///   XrplPathStep(currency: 'USD', issuer: 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B'),
/// ]);
/// ```
///
/// See: https://xrpl.org/docs/concepts/tokens/fungible-tokens/paths
@immutable
class XrplPath {
  /// Creates a path from an ordered list of steps.
  const XrplPath(this.steps);

  /// The ordered steps that make up this path.
  final List<XrplPathStep> steps;

  /// Converts this path to the JSON array shape used by the XRPL APIs.
  List<Map<String, dynamic>> toJson() =>
      steps.map((step) => step.toJson()).toList();

  @override
  bool operator ==(Object other) {
    if (other is! XrplPath || other.steps.length != steps.length) {
      return false;
    }
    for (var i = 0; i < steps.length; i++) {
      if (other.steps[i] != steps[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(steps);

  @override
  String toString() => 'XrplPath($steps)';
}
