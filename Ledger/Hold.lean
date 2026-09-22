/-
  Ledger.Hold — the lifecycle of a `credit_holds` row

  `services/ledger.md` §5–6. A hold reserves `amount` credits against an
  org's balance for the duration of a run (so two concurrent runs cannot
  each spend the same balance — the race itself is closed by the Postgres
  statement in `Ledger.Sql.Reserve`, not by anything here). Once held, a
  hold moves to exactly one of `settled` or `released`, never both and
  never twice: `HoldStep` indexes the transition by source and target
  phase, so there is no constructor a caller could apply to a hold that
  has already left `.held`.
-/

import Ledger.Credits

namespace Ledger

/-- The lifecycle phase of a `credit_holds` row, matching its `state`
    column (`services/ledger.md` §4). -/
inductive HoldPhase where
  | held
  | settled
  | released
  deriving BEq, Repr

/-- A single legal transition between hold phases. There is no constructor
    with `.settled` or `.released` as its source: nothing leaves those
    phases, so a hold settles (or releases) at most once by construction —
    a caller simply has no `HoldStep` value to apply a second time. -/
inductive HoldStep : HoldPhase → HoldPhase → Type where
  | settle : HoldStep .held .settled
  | release : HoldStep .held .released

/-- A `credit_holds` row: which org and run reserved how many credits. The
    lifecycle phase itself lives in Postgres (`services/ledger.md` §3 — this
    is the one piece of state the Lean layer does not try to own), so
    `Hold` here carries only the amount a `Settlement` is checked against. -/
structure Hold where
  amount : Credits
  deriving BEq, Repr

/-- A settlement of a hold: how many credits the run actually spent, with a
    proof it did not exceed what was held. This is the point where the
    warrant's `budget` caveat is actually enforced against reality, rather
    than merely re-checked (`services/ledger.md` §6, Tier 2) — a
    `Settlement h` cannot be constructed for an `actual` that overspends
    `h.amount`. -/
structure Settlement (h : Hold) where
  private mk ::
  actual : Credits
  within : actual ≤ h.amount

namespace Settlement

/-- The only way to build a `Settlement`: supply the amount actually spent
    together with the proof it stayed within the hold. -/
def of (h : Hold) (actual : Credits) (within : actual ≤ h.amount) : Settlement h :=
  ⟨actual, within⟩

end Settlement

end Ledger
