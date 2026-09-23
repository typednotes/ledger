/-
  Ledger.Sql.Migrate — apply `Ledger.Sql.history` to a local database

  **Production does not use this.** There, `typednotes-infra` reads the same
  `sql/*.sql` files at the release tag and applies them as a declared
  `postgresMigrations` history, ordered after the history that creates
  `orgs`/`users` (which this schema references) and before the `ledger`
  container rolls out.

  This is the local and scratch-database path: a minimal, sequential runner
  over the same embedded history, one session per migration. It does not
  track what has already run, so it is meant for a fresh database; it keeps
  no bookkeeping of its own because the history table in production belongs
  to `infra`, and a second, differently-shaped one here would invite the two
  to be mixed on one database.
-/

import Ledger.Sql.History
import Linen.Database.SQL.Pool

namespace Ledger.Sql

open Database.SQL.Pool
open Database.SQL.Session

/-- Apply every migration in `history`, in order, as one session each.
    Meant to be run once against a fresh database (`lake exe ledger
    migrate`); it does not track which migrations have already run. -/
def migrate (pool : Pool) : IO Unit := do
  for (id, sql) in history do
    match ← pool.use (Session.sql sql) with
    | .ok () => IO.println s!"applied {id}"
    | .error e => throw (IO.userError s!"migration {id} failed: {e}")

end Ledger.Sql
