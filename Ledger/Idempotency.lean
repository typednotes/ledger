/-
  Ledger.Idempotency — keys that are derived, not generated

  `services/ledger.md` §5, calling this "the highest-value type here":
  there is no constructor that lets a retry path invent a fresh random
  key, which is precisely how double-billing happens. `IdempotencyKey`'s
  constructor is private; the only way to produce one is `ofReserved`, a
  pure function of the authorized request and the attempt number, so
  retrying the same authorized request (any number of times, at any
  attempt count) reproduces the same key and collides with the `unique
  (idempotency_key)` index in `usage_events` instead of inserting a
  duplicate row.
-/

namespace Ledger

/-- The minimal projection of a `core`-authorized request that the ledger
    needs to key on: which org, which run, and the request itself.
    `core`'s actual warrant/request types are out of scope for this
    library (see `services/core.md`); `req` is left generic so any request
    type `core` and `broker` agree on can be threaded through here as long
    as it can be rendered deterministically. -/
structure Reserved (req : Type) [ToString req] where
  orgId : String
  runId : String
  request : req

/-- A key into `usage_events.idempotency_key`. Opaque outside this module:
    the private constructor means every `IdempotencyKey` in existence was
    produced by `ofReserved`. -/
structure IdempotencyKey where
  private mk ::
  value : String
  deriving BEq, Repr

/-- Derive the idempotency key for the `attempt`-th try of an authorized
    request. Pure and total in `r` and `attempt`, so calling it twice with
    the same arguments — exactly what a retry does — always yields the
    same key; `Statement.run` catching the resulting unique-violation *is*
    the idempotent path (`services/ledger.md` §7). -/
def IdempotencyKey.ofReserved {req : Type} [ToString req]
    (r : Reserved req) (attempt : Nat) : IdempotencyKey :=
  ⟨s!"{r.orgId}:{r.runId}:{toString r.request}:{attempt}"⟩

end Ledger
