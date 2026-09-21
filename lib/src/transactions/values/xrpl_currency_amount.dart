/// A currency amount that is either plain XRP or an issued currency -
/// the two forms XRPL's `Amount` binary type represents, used
/// wherever a transaction field can hold either (for example,
/// `OfferCreate`'s `TakerGets`/`TakerPays`).
///
/// Why this exists: `TakerGets`/`TakerPays` cannot be limited to
/// "XRP-only" the way `XrplPayment.amountDrops` was in Phase 4 -
/// trading only XRP for XRP would make an order meaningless. This
/// class makes the two valid shapes explicit and mutually exclusive
/// at the API level: [XrplCurrencyAmount.xrp] and
/// [XrplCurrencyAmount.issued] are the only ways to construct one, so
/// there is no way to accidentally mix XRP and issued-currency fields
/// together the way there would be with a single constructor taking
/// every field as optional.
///
/// Mirrors the same XRP-vs-issued-currency split
/// `XrplAmountSerializer` already has at the binary encoding layer
/// (`encodeXrpAmount` vs `encodeIssuedCurrencyAmount`) - this is the
/// model-layer equivalent of that same distinction, expected to be
/// reused wherever a future transaction type (AMM, path finding)
/// needs the same "XRP or issued currency" shape.
///
/// Not validated here - the same deferred-validation approach as
/// `XrplPayment.destinationTag` and other model fields: validation
/// happens where the value is actually encoded
/// (`XrplAmountSerializer`), not at construction, since these classes
/// use plain constructors kept simple for ergonomic
/// `const`/literal-style usage in application code, tests, and
/// examples.
///
/// Example:
/// ```dart
/// final sixXrp = XrplCurrencyAmount.xrp('6000000');
/// final twoGko = XrplCurrencyAmount.issued(
///   currency: 'GKO',
///   issuer: 'ruazs5h1qEsqpke88pcqnaseXdm6od2xc',
///   value: '2',
/// );
/// ```
///
/// See:
/// https://xrpl.org/docs/references/protocol/data-types/basic-data-types#specifying-currency-amounts
class XrplCurrencyAmount {
  /// Creates a plain XRP amount, in [drops] (1 XRP = 1,000,000
  /// drops).
  const XrplCurrencyAmount.xrp(String this.drops)
      : currency = null,
        issuer = null,
        value = null;

  /// Creates an issued-currency amount: [currency] (a 3-letter code
  /// or 40-character hex code), [issuer] (the account that issues
  /// it), and [value] (a decimal string, in the issued currency's own
  /// units, never drops).
  const XrplCurrencyAmount.issued({
    required this.currency,
    required this.issuer,
    required this.value,
  }) : drops = null;

  /// The XRP amount in drops, if this is a plain XRP amount; `null`
  /// for an issued-currency amount.
  final String? drops;

  /// The issued currency's code, if this is an issued-currency
  /// amount; `null` for plain XRP.
  final String? currency;

  /// The issuing account's address, if this is an issued-currency
  /// amount; `null` for plain XRP.
  final String? issuer;

  /// The issued currency's value, if this is an issued-currency
  /// amount; `null` for plain XRP.
  final String? value;

  /// Whether this amount is plain XRP (as opposed to an issued
  /// currency).
  bool get isXrp => drops != null;

  /// Converts this amount into the JSON shape XRPL expects: a plain
  /// drops string for XRP, or a `{currency, issuer, value}` object
  /// for an issued currency.
  dynamic toJson() {
    if (isXrp) return drops;
    return {
      'currency': currency,
      'issuer': issuer,
      'value': value,
    };
  }
}
