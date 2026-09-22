import Ledger.Entry

open Ledger

-- Sign comes from the constructor, not from the caller.
#guard (Entry.purchase 100 ⟨"evt_1"⟩).delta == 100
#guard (Entry.grant 50 ⟨"trial"⟩).delta == 50
#guard (Entry.usage 30 ⟨"ue_1"⟩).delta == -30
#guard (Entry.usageRefund 30 ⟨"entry_1"⟩).delta == 30
#guard (Entry.chargeback 100 ⟨"evt_2"⟩).delta == -100

-- `balance` is the fold: a purchase followed by usage nets to the difference.
#guard balance [Entry.purchase 100 ⟨"evt_1"⟩, Entry.usage 30 ⟨"ue_1"⟩] == 70
#guard balance ([] : List Entry) == 0

-- `balance_append`: folding a prefix and a suffix separately agrees with
-- folding the whole list — this is what licenses snapshotting.
example : balance ([Entry.purchase 100 ⟨"evt_1"⟩] ++ [Entry.usage 30 ⟨"ue_1"⟩])
    = balance [Entry.purchase 100 ⟨"evt_1"⟩] + balance [Entry.usage 30 ⟨"ue_1"⟩] :=
  balance_append _ _
