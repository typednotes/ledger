# AGENTS.md

Guidance for working in the **ledger** Lean service (`typednotes/ledger`).

`ledger` is the org's usage-ledger service — it holds `usage_events`,
`credit_ledger`, and `credit_holds` in Postgres, and runs the periodic
sweeper that releases expired holds. It builds on `linen`
(`typednotes/linen`), the org's Lean 4 standard library, for everything
Postgres/SQL, and follows `linen`'s own conventions below.

## Project layout

- Library sources live under `Ledger/`, mirroring their module path
  (e.g. `Ledger/Sql/Reserve.lean` is module `Ledger.Sql.Reserve`).
- Every source module must be imported from the library root `Ledger.lean`.
- Tests live under `LedgerTests/`, mirroring the source tree with a `Test`
  suffix on the file name (e.g. `Ledger/Entry.lean` →
  `LedgerTests/Ledger/EntryTest.lean`), and are imported from
  `LedgerTests.lean`. The test library is named (and rooted at)
  `LedgerTests`, not `Tests` — `linen` itself declares a library rooted at
  `Tests`, and Lake claims a module-name root globally across the whole
  workspace, not per-package, so reusing `Tests` here collides with
  `linen`'s.
- The SQL schema lives under `sql/` as plain, numbered `.sql` migration
  files (`0001_init.sql`, …) — the only copy of the schema. `typednotes-infra`
  reads them from GitHub at the release tag and applies them in production
  (as an `infra` `postgresMigrations` history). `Ledger.Sql.history`
  (`Ledger/Sql/History.lean`) embeds them with `include_str` for
  `Ledger.Sql.migrate` (`lake exe ledger migrate`) on a local database; a new
  migration is a new file **and** a new line there. Shipped migrations are
  append-only — never edit one.

## Testing

- **Every module in `Ledger/` must have a counterpart under `LedgerTests/`
  with illustrative tests.** The test module mirrors the source path (with a
  `Test` suffix) and is added to the import list in `LedgerTests.lean`.
- Tests assert correctness with `#guard`, so building the `LedgerTests`
  library runs every check:

  ```
  lake build LedgerTests
  ```

- Prefer small, illustrative `#guard` examples that document intended
  behaviour. For `Prop`-valued definitions that cannot be decided by
  `#guard`, use `example ... := rfl` (or an explicit proof) to illustrate the
  law — see `LedgerTests/Ledger/EntryTest.lean`'s use of `balance_append`.
- A type-level guarantee that has no term to exhibit as a negative case
  (e.g. `HoldStep` has no constructor from `.settled`/`.released`) is
  documented as such in the test file rather than forced into a `#guard`.
- Building `ledger`'s executable links against `linen`'s native `libpq`
  FFI, so `libpq-dev`/`pkg-config` must be installed wherever this is built
  (CI installs them; see `lean_action_ci.yml`).

## Coding conventions

- **No `partial def`.** All recursion must be structural or have a proven
  termination argument — never use `partial` and never rely on a fuel
  parameter to dodge termination. The sweeper (`Ledger.Sweeper`) uses a
  `while !(← token.isCancelled) do ...` loop with `Std.CancellationToken`,
  matching `linen`'s own `System.TimeManager` pattern, rather than
  `partial def`.
- **No `sorry`.** Do not leave `sorry` in committed code unless it is
  genuinely unavoidable; if so, call it out explicitly.
- Prefer `linen`'s objects over re-wrapping them (e.g. `Database.SQL.Pool`,
  `Session`, `Statement`, `Encoders`/`Decoders`) — do not hand-roll SQL
  connection or (de)serialization code that `linen` already provides.
- Document definitions with doc-comments; mathematical statements may use
  LaTeX (`$...$` / `$$...$$`).
- Group code into clearly labelled sections with `── … ──` comment banners.

## No half-implemented features

If a feature (a safety check, a data model that is meant to cover several
cases, an API meant to apply uniformly across a set of kinds/types, ...) is
only wired up for some of the cases it should logically cover, that is not
"done for now" — it is a trap for whoever assumes it applies uniformly. A
2026-09-10 incident in the sibling `infra` project: an ownership/tagging
system was wired up for two kinds out of many, with every other kind silently
falling back to weaker, ledger-only behaviour; the gap was invisible until it
caused a real, destructive incident. Either implement a feature completely
for every case it claims to cover in the same change, or say loudly in the
code, the docs, and to the user exactly which cases it does **not** cover
yet — never let partial coverage look complete. When only part of a feature
can be done, stop and get explicit agreement from the user on the partial
scope before shipping it, rather than deciding unilaterally that "the common
case" is good enough.

## Importing external code

**`typednotes` is not external.** Libraries in the `typednotes` GitHub
organisation (`typednotes/linen`, `typednotes/secrets`, `typednotes/broker`,
`typednotes/core`, …) are first-party siblings of this one, not third-party
dependencies. Before implementing something here, check whether `linen`
already provides it (`Database/SQL/*`, `Time/*`, `Control/Concurrent/*`,
etc.) and use that rather than reimplementing it in `ledger`. If something
implemented here turns out to be broadly reusable rather than
ledger-specific, it belongs in `linen`, not duplicated here — move it over,
following `linen`'s own conventions (doc-comment banner, mirrored `Tests/`
module, `#guard` coverage), and depend on it from here instead.

## Releasing

`ledger` is not consumed as a Lean/git dependency — it is shipped as a
container image. `.github/workflows/docker-publish.yml` builds and pushes
`ghcr.io/typednotes/ledger` on every push to `main` (tagged `edge`) and on
`v*.*.*` tags (tagged with the matching semver and `latest`). There is no
separate version bump step in `lakefile.lean`; the image tag *is* the
version.

## Git

**Never run `git push`** (including `--tags`/`--force`), regardless of
branch. Commits and tags are fine to create locally; pushing is left to the
user to do themselves.
