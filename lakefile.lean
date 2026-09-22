import Lake
open Lake DSL

-- ── libpq link flags ──
--
-- `linen`'s own `postgres.o`/`linenffi` are linked into `linen`'s package via
-- its own `moreLinkArgs`, but that does not propagate to a *consumer's*
-- `lean_exe` — Lake resolves `moreLinkArgs` per package, and the final link
-- step for `ledger`'s executable is `ledger`'s own, not `linen`'s. Without
-- this, `lake build ledger:exe` fails with `undefined symbol: PQconnectdb`
-- and friends — exactly the "Consumer" gotcha `linen/AGENTS.md` documents,
-- just surfacing at the final link rather than at compile time, so it isn't
-- caught by building the `Ledger`/`Tests` libraries alone.
--
-- Copied from `linen`'s own `pkgConfig`/`pkgLinkFlags` helpers rather than
-- imported, since `moreLinkArgs` is evaluated per-package and `linen`'s
-- versions are not exposed as part of its public API.

/-- Run `pkg-config <args>` and return its stdout split into individual flags.
    Returns `#[]` when pkg-config (or the queried package) is unavailable. -/
def pkgConfig (args : Array String) : IO (Array String) := do
  let out ← IO.Process.output { cmd := "pkg-config", args }
  if out.exitCode != 0 then
    return #[]
  let normalized := (out.stdout.replace "\n" " ").replace "\t" " "
  return (normalized.splitOn " ").filter (· != "") |>.toArray

/-- Link flags for a pkg-config package: its `--libs`, plus an explicit
    `-L<libdir>` from `--variable=libdir` — needed because `pkg-config --libs`
    omits directories it considers "default" (e.g. Debian/Ubuntu's multiarch
    path), which Lean's bundled `ld.lld` does not search by default. -/
def pkgLinkFlags (pkg : String) : IO (Array String) := do
  let libs ← pkgConfig #["--libs", pkg]
  let libdir ← pkgConfig #["--variable=libdir", pkg]
  return (libdir.filter (· != "")).map ("-L" ++ ·) ++ libs

-- `mkDef` names the generated `def` via `mkIdent`, not a bare identifier
-- written inside the `` `(...) `` quotation: a bare identifier there is
-- hygienic (macro-scoped) and would not match the plain `pqLinkArgs`
-- reference below in `moreLinkArgs := pqLinkArgs`, failing with `unknown
-- identifier` even though the `def` was elaborated successfully.
open Lean Elab Command in
run_cmd do
  let mkDef (n : Name) (flags : Array String) : CommandElabM Unit := do
    let lits : Array (TSyntax `term) := flags.map (fun s => quote s)
    elabCommand (← `(def $(mkIdent n) : Array String := #[$lits,*]))
  let pq ← pkgLinkFlags "libpq"
  mkDef `pqLinkArgs pq

package ledger where
  version := v!"0.1.0"
  moreLinkArgs := pqLinkArgs

require linen from git "git@github.com:typednotes/linen.git" @ "v1.0.0"

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
