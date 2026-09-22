/-
  Ledger.Sql.Migrate — apply the schema in `sql/`

  A minimal, sequential migration runner: read every `sql/NNNN_*.sql` file
  in name order and run it as one session. There is exactly one migration
  today (`sql/0001_init.sql`, `services/ledger.md` §4 verbatim); this
  exists so `lake exe ledger migrate` has somewhere to grow as the schema
  evolves, without inventing a tracking table this project does not yet
  need.
-/

import Linen.Database.SQL.Pool

namespace Ledger.Sql

open Database.SQL.Pool
open Database.SQL.Session

/-- Directory containing the numbered `.sql` migration files, relative to
    the process's working directory (the container's `WORKDIR`). -/
def migrationsDir : System.FilePath := "sql"

/-- Apply every `.sql` file under `migrationsDir`, in filename order, as
    one statement each. Meant to be run once against a fresh database
    (`lake exe ledger migrate`); it does not track which migrations have
    already run. -/
def migrate (pool : Pool) : IO Unit := do
  let entries ← migrationsDir.readDir
  let sqlFiles := entries.filterMap fun e =>
    if e.fileName.endsWith ".sql" then some e.path else none
  let sorted := sqlFiles.qsort (fun a b => a.toString < b.toString)
  for file in sorted do
    let contents ← IO.FS.readFile file
    match ← pool.use (Session.sql contents) with
    | .ok () => IO.println s!"applied {file}"
    | .error e => throw (IO.userError s!"migration {file} failed: {e}")

end Ledger.Sql
