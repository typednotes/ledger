/-
  Ledger.Sql.Reserve — the one atomic statement that actually prevents
  double-spend

  `services/ledger.md` §3, §7: the no-double-spend property is a Postgres
  concurrency property, not a Lean one — two containers, two concurrent
  requests, one org, and no in-memory balance to protect under serverless
  hosting. The balance check and the hold insert must happen as one
  statement, never a read then a write, or two concurrent reservations can
  each see the same "before" balance and both succeed.

  This statement is exactly the one in `services/ledger.md` §7: it inserts
  a `credit_holds` row only if the org's current balance (ledger sum minus
  already-held sum) covers `amount`, returning the new hold's id, or no
  row at all if it does not. Zero rows back means denied — there is no
  advisory lock, and the application layer must not "check first, then
  insert": that read-then-write is the bug this statement exists to
  make impossible.

  Every parameter is cast (`$1::uuid`, `$3::bigint`): the driver sends
  parameters untyped, and Postgres cannot deduce one type for `$3` from both
  a `bigint` column and a `numeric` sum ("inconsistent types deduced for
  parameter $3"), nor coerce text into the `uuid` columns. Without the casts
  the statement is refused outright, which callers see as "denied".
-/

import Linen.Database.SQL.Statement
import Ledger.Credits

namespace Ledger.Sql

open Database.SQL.Statement
open Database.SQL.Encoders (Params)
open Database.SQL.Decoders (Value Row Result)

/-- Parameters for `reserve`: which org, which run, how many credits. -/
structure ReserveParams where
  orgId : String
  runId : String
  amount : Credits

/-- Attempt to reserve `amount` credits for `runId` against `orgId`'s
    balance. Succeeds with the new hold's id iff the org's balance minus
    its currently-held amount is at least `amount`; otherwise returns
    `none` — no exception, no partial state, nothing to roll back. -/
def reserve : Statement ReserveParams (Option String) :=
  { sql := "
      insert into credit_holds (org_id, run_id, amount, state, expires_at)
      select $1::uuid, $2::uuid, $3::bigint, 'held', now() + interval '15 minutes'
      where (
        select coalesce(sum(delta), 0) from credit_ledger where org_id = $1::uuid
      ) - (
        select coalesce(sum(amount), 0) from credit_holds
         where org_id = $1::uuid and state = 'held'
      ) >= $3::bigint
      returning id::text;
    "
    encode := (Params.triple Params.text Params.text Params.nat).contramap
      (fun p => (p.orgId, p.runId, p.amount))
    decode := Result.maybeRow (Row.column Value.text) }

end Ledger.Sql
