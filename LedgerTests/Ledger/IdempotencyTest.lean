import Ledger.Idempotency

open Ledger

-- A retry of the same authorized request at the same attempt number
-- reproduces the same key …
#guard IdempotencyKey.ofReserved (req := String)
    { orgId := "org_1", runId := "run_1", request := "call-mistral" } 0
  == IdempotencyKey.ofReserved (req := String)
    { orgId := "org_1", runId := "run_1", request := "call-mistral" } 0

-- … while a different attempt number, org, run, or request produces a
-- different key, so successive attempts of the same run do not collide
-- with each other on the `unique (idempotency_key)` index either.
#guard IdempotencyKey.ofReserved (req := String)
    { orgId := "org_1", runId := "run_1", request := "call-mistral" } 0
  != IdempotencyKey.ofReserved (req := String)
    { orgId := "org_1", runId := "run_1", request := "call-mistral" } 1

#guard IdempotencyKey.ofReserved (req := String)
    { orgId := "org_1", runId := "run_1", request := "call-mistral" } 0
  != IdempotencyKey.ofReserved (req := String)
    { orgId := "org_2", runId := "run_1", request := "call-mistral" } 0
