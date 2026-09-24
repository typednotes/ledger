/-
  Tests for `Ledger.Sql.Reserve`: the statement text, which only a live
  Postgres can execute. Pinned so the casts that make it acceptable to
  Postgres at all — against the `uuid`/`bigint` columns of `0001_init.sql`,
  with the untyped parameters the driver sends — cannot be dropped silently.
-/
import Ledger.Sql.Reserve

open Ledger.Sql

namespace LedgerTests.Ledger.Sql.Reserve

private def has (needle : String) : Bool := (reserve.sql.splitOn needle).length > 1

#guard has "select $1::uuid, $2::uuid, $3::bigint, 'held', now() + interval '15 minutes'"
#guard has "from credit_ledger where org_id = $1::uuid"
#guard has "where org_id = $1::uuid and state = 'held'"
#guard has ">= $3::bigint"
#guard has "returning id::text"
-- No bare parameter is left for Postgres to infer.
#guard !has "$1," && !has "$1\n" && !has "$3\n"

end LedgerTests.Ledger.Sql.Reserve
