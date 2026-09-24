import Ledger.Sql.Grant
import Ledger.Sql.History
import Ledger.Entry

open Ledger
open Ledger.Sql

-- ── The contract: the literal SQL ──

-- The typednotes app issues this exact text (`docs/connections.md` §6); it
-- cannot import Lean, so changing it here must break the build.
#guard grantSql ==
  "insert into credit_ledger (org_id, delta, reason, idempotency_key)\n" ++
  "values ($1::uuid, $2, 'grant', $3)\n" ++
  "on conflict (idempotency_key) do nothing"

-- The statement runs the contract text, not a copy of it.
#guard grant.sql == grantSql

-- ── Welcome key ──

#guard welcomeKey "0b6f1c1e-5d1a-4c2e-9f3a-2a7d8e4b9c10" ==
  "welcome:0b6f1c1e-5d1a-4c2e-9f3a-2a7d8e4b9c10"

-- ── Parameters ──

-- `$1`, `$2`, `$3` are org id, amount, key — in that order.
#guard grant.encode.width == 3
#guard grant.encode.encode { orgId := "org-1", amount := 1000, key := welcomeKey "org-1" }
  == #[some "org-1", some "1000", some "welcome:org-1"]

-- `reason = 'grant'` with a positive delta is `Entry.grant`'s row.
#guard (Entry.grant 1000 ⟨"welcome"⟩).delta == 1000

-- ── Migration ──

-- The key column the `on conflict` target needs is added by `0002`, and is
-- unique (NULLs distinct, so rows without a key are unaffected).
#guard (history.lookup "0002").any fun sql =>
  (sql.splitOn "alter table credit_ledger add column idempotency_key text unique").length > 1
