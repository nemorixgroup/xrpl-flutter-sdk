/// The strategy for choosing a transaction's `Fee` value from the
/// server's `fee` command response.
///
/// Why this exists: the official `fee` command reports several
/// already-calculated values at once (`base_fee`, `minimum_fee`,
/// `open_ledger_fee`, `median_fee`), each a different tradeoff
/// between cost and how quickly a transaction is likely to be
/// included. This SDK doesn't calculate any of them itself - each
/// value is read directly from the server's response - this enum
/// only selects which one `autofill` uses.
///
/// See:
/// https://xrpl.org/docs/references/http-websocket-apis/public-api-methods/server-info-methods/fee
enum XrplFeeStrategy {
  /// The fee needed to be included in the current open ledger - the
  /// default. Per official guidance in "Reliable Transaction
  /// Submission," prioritizing prompt inclusion is usually the safer
  /// choice over minimizing cost.
  openLedger,

  /// The absolute minimum transaction cost. Cheaper, but a
  /// transaction at this fee may be queued for a later ledger instead
  /// of the current one during periods of network congestion.
  minimum,

  /// The median transaction cost among transactions in the previous
  /// validated ledger.
  median,

  /// The unscaled base transaction cost, before adjusting for current
  /// network load.
  base,
}
