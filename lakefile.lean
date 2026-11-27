import Lake
open Lake DSL

package ledger where
  version := v!"0.3.11"

-- `linen` is a public repo, so the plain `https://` URL resolves with no
-- credentials — unlike `git@github.com:...`, which git treats as an SSH
-- URL and always tries to authenticate, public repo or not.
require linen from git "https://github.com/typednotes/linen.git" @ "v4.1.0"

@[default_target]
lean_lib Ledger

-- Named (and rooted at) `LedgerTests`, not `Tests` — `linen` itself declares
-- a library rooted at `Tests`, and Lake claims a module-name root globally
-- across the whole workspace, not per-package. Rooting this library at
-- `Tests` too made Lake resolve `Tests.Ledger.*` against *linen's* `Tests/`
-- directory (which has no `Ledger/` subtree), failing with "no such file or
-- directory" instead of building this package's own files.
lean_lib LedgerTests

lean_exe ledger where
  root := `Main
