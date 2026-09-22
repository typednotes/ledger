/-
  Ledger.Ids — opaque identifiers owned by other services

  `services/ledger.md` §5 writes `Entry`'s constructors against
  `StripeEventId`, `UsageEventId`, `EntryId` and `GrantReason` without
  defining them there, since they are foreign keys into rows that `core`,
  `broker` and Stripe own, not values the ledger constructs. Each is a thin
  wrapper around the underlying `uuid`/`text` column so `Entry`'s
  constructors cannot be applied to the wrong kind of string, without
  pretending the ledger owns their lifecycle.
-/

namespace Ledger

/-- Primary key of a `usage_events` row (`services/ledger.md` §4). -/
structure UsageEventId where
  value : String
  deriving BEq, Repr, Inhabited

/-- Primary key of a `credit_ledger` row (`services/ledger.md` §4). -/
structure EntryId where
  value : String
  deriving BEq, Repr, Inhabited

/-- Stripe's event id, carried on `purchase`/`chargeback` entries so the
    webhook handler's idempotency check (`services/ledger.md` §7, Tier 5)
    has something to key on. -/
structure StripeEventId where
  value : String
  deriving BEq, Repr, Inhabited

/-- Why credits were granted outside of a Stripe purchase (free tier, trial,
    goodwill, ...). Kept open-ended as free text; see `services/ledger.md`
    §9 on expiring grants, which this type does not yet model. -/
structure GrantReason where
  value : String
  deriving BEq, Repr, Inhabited

end Ledger
