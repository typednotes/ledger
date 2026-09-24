/-
  Ledger.Sql.Grant — the idempotent credit-grant statement

  A grant is the SQL form of `Ledger.Entry.grant`: a `credit_ledger` row
  with `reason = 'grant'` and a positive `delta` (the constructor's
  `Credits` amount, a `Nat`, so the sign cannot be wrong here either).
  `Entry.grant`'s `GrantReason` is the *why*; in SQL that why is carried by
  the grant's idempotency key (e.g. `welcome:{org_id}`), while the
  `reason` column stays the fixed string `'grant'`.

  Grants must be idempotent: the typednotes app issues the welcome grant
  when it creates an org, and it retries on failure — a double grant is
  free money. `sql/0002_credit_ledger_idempotency.sql` adds the unique
  `credit_ledger.idempotency_key` column, and this statement inserts with
  `on conflict (idempotency_key) do nothing`, so replaying a grant with the
  same key is a no-op rather than a second credit.

  **The literal SQL is the contract.** The typednotes app (Rust) cannot
  import Lean, so it issues exactly `grantSql` itself
  (`typednotes/typednotes` `docs/connections.md` §6). `ledger` owns the
  statement; `LedgerTests/Ledger/Sql/GrantTest.lean` pins its text, so any
  change here fails the build until the contract (and the app) are updated
  in step.
-/

import Linen.Database.SQL.Pool
import Linen.Database.SQL.Statement
import Ledger.Credits

namespace Ledger.Sql

open Database.SQL.Pool
open Database.SQL.Statement
open Database.SQL.Encoders (Params)
open Database.SQL.Decoders (Result)

-- ── The contract ──

/-- The canonical grant statement, verbatim as the typednotes app issues it
    (`docs/connections.md` §6). Parameters: `$1` the org id (a uuid, as
    text), `$2` the amount in credits, `$3` the idempotency key. Inserts
    one `credit_ledger` row with `reason = 'grant'`, or nothing if a row
    with the same `idempotency_key` already exists. -/
def grantSql : String :=
  "insert into credit_ledger (org_id, delta, reason, idempotency_key)\n" ++
  "values ($1::uuid, $2, 'grant', $3)\n" ++
  "on conflict (idempotency_key) do nothing"

/-- The idempotency key of an org's welcome grant: `welcome:{orgId}`.
    One per org, so however many times the app retries org creation's
    grant, the org is credited once. -/
def welcomeKey (orgId : String) : String := s!"welcome:{orgId}"

-- ── Statement ──

/-- Parameters for `grant`: which org, how many credits, and the key that
    makes replays no-ops. `amount` is `Credits` (a `Nat`), matching
    `Entry.grant`'s non-negative amount; the app does not issue a grant at
    all when its configured amount is `0`. -/
structure GrantParams where
  orgId : String
  amount : Credits
  key : String

/-- `grantSql` as a typed statement. Decodes to `true` iff a row was
    inserted (`INSERT 0 1`), `false` iff the key had already been granted
    (`INSERT 0 0`, the `do nothing` branch). -/
def grant : Statement GrantParams Bool :=
  { sql := grantSql
    encode := (Params.triple Params.text Params.nat Params.text).contramap
      (fun p => (p.orgId, p.amount, p.key))
    decode := Result.map (· > 0) Result.rowsAffected }

/-- Run `grant` on a pooled connection. `.ok true`: credited now;
    `.ok false`: already credited under this key, nothing changed. Safe to
    retry on any outcome. -/
def issueGrant (pool : Pool) (p : GrantParams) : IO (Except PoolError Bool) :=
  pool.use (grant.run p)

end Ledger.Sql
