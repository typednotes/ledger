/-
  Ledger.Entry — append-only credit-ledger entries

  Ported essentially verbatim from `services/ledger.md` §5–6. Each
  constructor fixes the sign of its `Credits` amount, so the SQL `reason`
  column's ambiguity — `'refund'` could mean returning credits for bad
  usage or clawing back a purchase, opposite signs — cannot resurface in
  Lean: there is one constructor per sign, not one text column carrying
  both a reason and an implicit sign.

  `balance` is the reconstruction function *and* the domain function at
  once (`services/ledger.md` §8): a `credit_ledger` balance is nothing but
  this fold over its rows.
-/

import Ledger.Credits
import Ledger.Ids

namespace Ledger

/-- A single row of `credit_ledger` (`services/ledger.md` §4), typed so the
    sign of `amount` is fixed by the constructor rather than carried
    separately in a `reason` column. -/
inductive Entry where
  /-- A Stripe payment landing as credits. (+) -/
  | purchase (amount : Credits) (stripe : StripeEventId)
  /-- Credits granted outside of a purchase (free tier, trial, goodwill). (+) -/
  | grant (amount : Credits) (reason : GrantReason)
  /-- Credits spent recording a `usage_events` row. (−) -/
  | usage (amount : Credits) (event : UsageEventId)
  /-- Credits returned for bad usage — the opposite of `usage`, not of
      `purchase`. (+) -/
  | usageRefund (amount : Credits) (entry : EntryId)
  /-- A Stripe chargeback clawing back a purchase. (−) -/
  | chargeback (amount : Credits) (stripe : StripeEventId)
  deriving BEq, Repr

/-- The signed effect of an entry on the org's balance. -/
def Entry.delta : Entry → Int
  | .purchase a _ | .grant a _ | .usageRefund a _ => (a : Int)
  | .usage a _ | .chargeback a _ => -(a : Int)

/-- An org's balance is the fold of every entry ever recorded for it.
    `services/ledger.md` §4 notes the balance is derived, never stored —
    this is that derivation. -/
def balance (es : List Entry) : Int := es.foldl (fun b e => b + e.delta) 0

/-- Folding `balance`'s step function from a starting accumulator `c` just
    adds `c` to folding from zero — the step function is `(· + ·)` composed
    with `Entry.delta`, so the initial accumulator passes through
    additively. The private helper `balance_append` needs. -/
private theorem foldl_delta_add (fs : List Entry) (c : Int) :
    fs.foldl (fun b e => b + e.delta) c = c + fs.foldl (fun b e => b + e.delta) 0 := by
  induction fs generalizing c with
  | nil => simp
  | cons e fs ih =>
    show fs.foldl (fun b e => b + e.delta) (c + e.delta)
        = c + fs.foldl (fun b e => b + e.delta) (0 + e.delta)
    rw [ih (c + e.delta), ih (0 + e.delta)]
    omega

/-- Folding is compositional: a balance computed over a prefix and a
    balance computed over the remainder always agree with folding the
    whole list at once. This is what licenses snapshotting a balance at a
    cutoff and folding only newer rows (`services/ledger.md` §6, Tier 3) —
    without it, caching a balance would be a guess, not a fact. -/
theorem balance_append (es fs : List Entry) :
    balance (es ++ fs) = balance es + balance fs := by
  simp only [balance, List.foldl_append]
  exact foldl_delta_add fs (es.foldl (fun b e => b + e.delta) 0)

end Ledger
