# Ledger v0.3.8 — strict type checking

Released on the user's request: agent instructions and strict type checking only;
no user-visible change.

## Changes

- `lakefile.lean` turns `autoImplicit` and `relaxedAutoImplicit` off for the
  package, and CI builds with `--wfail` (the lean-action build and the
  `lake build --wfail LedgerTests` step), so any warning, including
  `declaration uses 'sorry'`, fails the build. The existing sources already
  satisfied both settings; no code change was needed.
- `AGENTS.md` follows the agents-md standard v3. The "never run `git push`"
  override remains; commits and tags now follow the standard rules.

No SQL migration, schema, hold arithmetic, grant idempotency or settlement wire
change. The embedded `Ledger.Sql.history` still holds migrations 0001–0003.

## Verification

Locally: `lake build --wfail`, `lake build --wfail LedgerTests` and
`lake build --wfail ledger` (executable) passed with no warnings, and the
offline release-gate regressions (`bash ci/test-require-main-ci.sh`, 50 cases)
passed.

## Publication

The release commit and annotated `v0.3.8` tag are prepared locally; publication
is the user's action. Push main and `v0.3.8` together; the image publisher waits
for that exact commit's main CI. Existing tags remain immutable.
