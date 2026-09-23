/-
  Ledger.Sql.History — the schema's migration history, embedded

  `sql/*.sql` is the schema, and the only copy. This module embeds those
  files with `include_str` so `Ledger.Sql.migrate` (`lake exe ledger
  migrate`) can apply them to a local database without depending on a
  working directory — the container image never shipped `sql/`.

  Production does not read this module: `typednotes-infra` reads the same
  `.sql` files from GitHub at the release tag and applies them as a declared
  `postgresMigrations` history, ordered after the app's history because this
  schema `references orgs(id)` (infra reads that from the SQL).

  **Adding a migration:** add `sql/NNNN_description.sql` and append one line
  here. Shipped migrations are append-only — never edit one.

  Lake does not track the `.sql` files as inputs of this module and traces
  by content hash, so after editing one locally run `lake clean`.
-/

namespace Ledger.Sql

/-- The full history, oldest first, as `(id, sql)`: `id` is the numeric
    prefix of the file name, and ids sort in application order. -/
def history : List (String × String) :=
  [ ("0001", include_str "../../sql/0001_init.sql") ]

end Ledger.Sql
