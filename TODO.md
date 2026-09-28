# TODO

Suggestions from the linen v1.6.1 dependency review (2026-09-28). Nothing here
blocks the bump — ledger uses none of the modules linen 1.6.x changed. Each
item names where it comes from; re-check before acting.

Moves into linen follow linen's `AGENTS.md` ("Importing external code"): the
linen change and the deletion of ledger's copy happen in the same pass.

## CI

- [ ] **Build the executable, not only `LedgerTests`.** CI runs
  `lake build LedgerTests` (`.github/workflows/lean_action_ci.yml:16`); no test
  imports `Main`, so the copied libpq link recipe is only exercised by the
  Docker publish. linen's `AGENTS.md` records a bug that only an executable
  link (`Scrt1.o`) exposes. Add `lake build ledger`, and a macOS leg for the
  lakefile's `.dylib` branch (`lakefile.lean:51`). (S)

## Building blocks to share

- [ ] **Typed environment readers.** `Main.lean:11-18` (`DATABASE_URL` →
  `PoolSettings`) is the same as liaison's `Main.lean:14-26`; lun and lode
  duplicate `secondsEnv`. ledger range-checks the port (`Main.lean:30-36`);
  lun, lode and liaison use `toUInt16`, which wraps. A `System.Environment`
  module in linen plus `Settings.fromEnv`, adopted by all four services. (S–M)
- [ ] **A health check with a probe.** linen's `healthCheck`
  (`Linen/Network/WebApp/Extra/Middleware/HealthCheckEndpoint.lean:18-23`)
  always answers 200, so `Ledger/Health.lean:31-42` hand-rolls a 503 for a
  stopped sweeper; lun and liaison hand-roll theirs too. A
  `healthCheckWith path probe` in linen. (S)
- [ ] **Reservation SQL is shared with liaison** (`liaison/Liaison/Budget.lean`
  repeats `Ledger/Sql/Reserve.lean`). Application logic, so not linen: expose a
  pure module here that liaison imports. (M)

## Workarounds that linen could remove

- [ ] **libpq for consumers' executables.** `lakefile.lean:26-76` copies
  `pkgConfig`/`pkgAbsoluteLibs` because Lake does not pass a dependency's
  `moreLinkArgs` to a dependent's executable; six repos carry the copy. An idea
  to try in linen: Lake 4.34 adds each imported library's `moreLinkObjs` to the
  executable link (`Lake/Build/Module.lean:1297-1303`), so a `moreLinkObjs`
  target yielding libpq's absolute path might carry it without the `-L` that
  shadows glibc. Unverified — prove it in linen's consumer CI job first. (M)
- [ ] **One consumer native-dependency list.** The same apt line is in
  `Dockerfile:11-14`, CI, and four siblings; linen's own
  `setup-native-deps` action is for linen's tests (keyrings) and omits
  zlib/unzip. A consumer-facing action or list in linen. (S)

## Small

- [ ] `Ledger/Sweeper.lean:56` sleeps with a `UInt32` of milliseconds, which
  overflows past ~49 days of interval. (XS)
