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
-- The flags name `libpq`'s file outright (`pkgAbsoluteLibs`) instead of
-- adding its directory to the linker's search path. On Linux that directory
-- is `/usr/lib/<multiarch>`, which also holds the *system* `libc.so`: an
-- `-L` for it makes `-lc` resolve there instead of to the glibc Lean
-- bundles, and Lean's vendored `Scrt1.o` then fails the link with
-- `undefined symbol: __libc_csu_init` (the compat symbol glibc 2.34
-- dropped). Naming the file adds nothing to the search order, so the
-- bundled glibc keeps winning. This is the recipe `linen` hands consumers
-- (its CI's consumer job, `linen/docs/linking.md`), used here on every
-- platform, as there: on macOS it names Homebrew's keg-only
-- `libpq.dylib`, which is exactly what the `-L` was needed for.
--
-- Copied from `linen`'s own `pkgConfig`/`pkgAbsoluteLibs` rather than
-- imported: a dependency's lakefile definitions are not in scope in a
-- consumer's lakefile.

/-- Run `pkg-config <args>` and return its stdout split into individual flags.
    Returns `#[]` when pkg-config (or the queried package) is unavailable. -/
def pkgConfig (args : Array String) : IO (Array String) := do
  let out ← IO.Process.output { cmd := "pkg-config", args }
  if out.exitCode != 0 then
    return #[]
  let normalized := (out.stdout.replace "\n" " ").replace "\t" " "
  return (normalized.splitOn " ").filter (· != "") |>.toArray

/-- Link flags for a pkg-config package that name each library file outright
    (`<libdir>/libfoo.so`, or `.dylib` on macOS) rather than adding its
    directory to `-L` (see the section comment). Every `-L` from `--libs` is
    dropped; an `-lfoo` whose file is absent from `--variable=libdir` stays
    `-lfoo`, so a distro with an unusual layout still gets a chance. -/
def pkgAbsoluteLibs (pkg : String) : IO (Array String) := do
  let libs ← pkgConfig #["--libs", pkg]
  let libdirs ← pkgConfig #["--variable=libdir", pkg]
  let libdir : Option String := (libdirs.filter (· != ""))[0]?
  let ext := if System.Platform.isOSX then "dylib" else "so"
  let mut out : Array String := #[]
  for tok in libs do
    if tok.startsWith "-L" then
      continue                                  -- deliberately dropped
    else if tok.startsWith "-l" then
      let name := (tok.drop 2).toString
      match libdir with
      | some d =>
        let candidate : System.FilePath := (d : System.FilePath) / s!"lib{name}.{ext}"
        if ← candidate.pathExists then
          out := out.push candidate.toString
        else
          out := out.push tok
      | none => out := out.push tok
    else
      out := out.push tok
  return out

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
  let pq ← pkgAbsoluteLibs "libpq"
  mkDef `pqLinkArgs pq

package ledger where
  version := v!"0.3.7"
  moreLinkArgs := pqLinkArgs

-- `linen` is a public repo, so the plain `https://` URL resolves with no
-- credentials — unlike `git@github.com:...`, which git treats as an SSH
-- URL and always tries to authenticate, public repo or not.
require linen from git "https://github.com/typednotes/linen.git" @ "v1.9.2"

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
