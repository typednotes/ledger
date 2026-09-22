import Ledger.Hold

open Ledger

-- `HoldStep` has a value from `.held` to `.settled` and to `.released` …
example : HoldStep .held .settled := HoldStep.settle
example : HoldStep .held .released := HoldStep.release

-- … but there is no `HoldStep .settled _` or `HoldStep .released _`
-- constructor at all: a hold cannot settle twice, or settle after release,
-- because there is no term a caller could write to do so. The absence of
-- such a value is the proof; it cannot be exhibited as a `#guard`.

-- A `Settlement` within budget can be constructed …
#guard (Settlement.of (Hold.mk 100) 60 (by decide)).actual == 60

-- … and its `within` field is the proof that it never exceeds the hold,
-- checked by the type at construction time rather than at every read.
example (h : Hold) (s : Settlement h) : s.actual ≤ h.amount := s.within
