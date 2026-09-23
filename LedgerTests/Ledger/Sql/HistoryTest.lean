import Ledger.Sql.History

open Ledger.Sql

-- The history as of this release: exactly the files in `sql/`.
#guard history.map (·.1) = ["0001"]

-- Ids strictly increase, so list order *is* application order — the rule
-- `infra`'s `historyIsSound` checks again on the consumer side.
#guard (history.zip (history.drop 1)).all (fun (a, b) => a.1 < b.1)

-- Every migration is real SQL, not an empty file `include_str` read happily.
#guard history.all (fun (_, sql) => !sql.trimAscii.isEmpty)

-- `0001` is `services/ledger.md` §4: the three tables, and the foreign keys
-- into `core`'s `orgs` from which `typednotes-infra` infers that this history
-- applies after the app's.
#guard history.head?.any fun (_, sql) =>
  (sql.splitOn "create table usage_events").length > 1 &&
  (sql.splitOn "create table credit_ledger").length > 1 &&
  (sql.splitOn "create table credit_holds").length > 1 &&
  (sql.splitOn "references orgs(id)").length > 1
