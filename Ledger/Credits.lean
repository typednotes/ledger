/-
  Ledger.Credits — the billing unit

  `services/ledger.md` §2, §5: money is integers. `Credits` counts a
  non-negative amount (a negative purchase or a negative hold is
  unrepresentable by construction); `Micros` is signed money, used for the
  `cost_micros`/`price_micros` columns in `usage_events`, which record what
  we paid a provider and what we charged a customer and may legitimately
  be adjusted (e.g. by a credit note) into the negative.

  `Data/Rat`, `Data/Fixed` and `Data/Float` are deliberately not imported
  anywhere in this library: every quantity here is an exact integer count,
  never an approximation.
-/

namespace Ledger

/-- A non-negative count of the billing unit. Matches `broker`'s `budget`
    caveat type (`services/ledger.md` §5), so spend authority checked at
    warrant-attenuation time and balance arithmetic checked here cannot
    drift apart by using different representations of the same quantity. -/
abbrev Credits := Nat

/-- Signed money, in millionths of the smallest currency unit (a "micro").
    Used for `cost_micros`/`price_micros`, which are what we paid a
    provider and what we charged a customer respectively — see
    `services/ledger.md` §4 point 2 on why the two must stay separate
    columns rather than a single "amount". -/
abbrev Micros := Int

end Ledger
