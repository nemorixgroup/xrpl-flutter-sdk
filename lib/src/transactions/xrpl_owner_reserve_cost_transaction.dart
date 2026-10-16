/// Marks a transaction type whose transaction cost (its `Fee`) is the
/// network's incremental owner reserve instead of the usual base fee.
///
/// Why this exists: `autofill` normally sets `Fee` from the `fee`
/// command's estimates, which are expressed for an ordinary
/// transaction. A few transaction types, such as `AMMCreate`, must
/// instead destroy at least the incremental owner reserve. Rather than
/// adding a member to `XrplTransaction` that every existing
/// transaction type would have to implement, this marker lets
/// `autofill` ask one question, `transaction is
/// XrplOwnerReserveCostTransaction`, and read the reserve from the
/// network only for the types that need it.
///
/// It has no members on purpose: being a member of this group is the
/// whole message.
///
/// See:
/// https://xrpl.org/docs/references/protocol/transactions/types/ammcreate
abstract interface class XrplOwnerReserveCostTransaction {}
