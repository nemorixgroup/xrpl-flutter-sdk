import 'package:meta/meta.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

/// Converts a `ripple_path_find`/`path_find` **destination** amount to
/// its JSON shape: either the literal `"-1"` or an [XrplCurrencyAmount].
///
/// Per the official specification, `-1` requests a path that delivers as
/// much as possible while spending no more than `send_max` (if given).
/// The literal string `"-1"` is the XRP form of that request; for an
/// issued currency, pass an [XrplCurrencyAmount.issued] whose `value` is
/// `'-1'` instead.
///
/// Why this exists: `ripplePathFind` and `pathFindCreate` share the same
/// amount rules, so they live in one place instead of being duplicated.
/// Only `destination_amount` accepts the `"-1"` shortcut; see
/// [pathFindSendMaxJson] for `send_max`, which does not.
///
/// Throws an [ArgumentError] for any other type, so a mistake fails
/// immediately and clearly, not as a confusing server-side error later.
///
/// Internal to this SDK, not part of the public API.
@internal
dynamic pathFindDestinationAmountJson(Object amount) {
  if (amount is String && amount == '-1') return amount;
  if (amount is XrplCurrencyAmount) return amount.toJson();
  throw ArgumentError(
    'destinationAmount must be the literal string "-1" or an '
    'XrplCurrencyAmount, got: $amount',
  );
}

/// Converts a `ripple_path_find`/`path_find` **send_max** amount to its
/// JSON shape: an [XrplCurrencyAmount].
///
/// The literal `"-1"` is deliberately rejected: per the official
/// specification it only has meaning as a `destination_amount`
/// ("deliver the maximum possible within send_max"). A `send_max` is the
/// cap on what the sender will spend, so it has to be an actual amount.
///
/// Throws an [ArgumentError] for any other type (including `"-1"`).
///
/// Internal to this SDK, not part of the public API.
@internal
dynamic pathFindSendMaxJson(Object amount) {
  if (amount is XrplCurrencyAmount) return amount.toJson();
  throw ArgumentError(
    'sendMax must be an XrplCurrencyAmount (the literal "-1" is only '
    'valid for destinationAmount), got: $amount',
  );
}
