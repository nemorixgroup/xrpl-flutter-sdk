/// The shared shape every XRPL transaction type in this SDK
/// implements (`XrplPayment`, `XrplTrustSet`, and future types added
/// in later phases).
///
/// Why this exists: `autofill` needs to fill in [sequence], [fee],
/// and [lastLedgerSequence] the same way regardless of which
/// transaction type it's given - it shouldn't need a separate
/// `autofillPayment`, `autofillTrustSet`, `autofillOfferCreate`, and
/// so on, repeating the same logic for every transaction type this
/// SDK adds over time. This interface is what makes one generic
/// `autofill<T extends XrplTransaction>` function possible instead.
abstract class XrplTransaction {
  /// Const constructor for subclasses, so each concrete transaction
  /// type (`XrplPayment`, `XrplTrustSet`, and future types) can
  /// itself be declared `const` when none of its fields need to be
  /// computed at runtime.
  const XrplTransaction();

  /// The account sending this transaction.
  String get account;

  /// The sending account's sequence number, if already set.
  int? get sequence;

  /// The transaction cost in drops, if already set.
  String? get fee;

  /// The last ledger index this transaction is valid in, if already
  /// set.
  int? get lastLedgerSequence;

  /// Returns a copy of this transaction with the given fields
  /// replaced. Each concrete transaction type overrides this to
  /// return its own type (for example, `XrplPayment.copyWith`
  /// returns `XrplPayment`), which Dart allows for overriding methods
  /// even though this interface declares the broader
  /// `XrplTransaction` return type.
  XrplTransaction copyWith({
    int? sequence,
    String? fee,
    int? lastLedgerSequence,
  });

  /// Converts this transaction into the JSON shape XRPL expects.
  Map<String, dynamic> toJson();
}
