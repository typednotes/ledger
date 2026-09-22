# ledger

The `typednotes` usage-ledger service, in Lean 4 on
[`linen`](https://github.com/typednotes/linen).

Implements `docs/services/ledger.md` from `typednotes/typednotes`:
records `usage_events`, holds a `credit_ledger` balance bounded by
`credit_holds`, and proves the arithmetic and hold lifecycle sound in Lean
— Postgres itself enforces the one property Lean types cannot: that two
concurrent holds can never together overspend a balance.

> Lean makes the arithmetic and the lifecycle correct. Postgres makes the
> concurrency correct.

## Layout

- `Ledger/` — core types and proofs:
  - `Credits.lean` — `Credits := Nat`, `Micros := Int`.
  - `Ids.lean` — foreign-key wrapper types owned by other services.
  - `Entry.lean` — the `credit_ledger` row type, `balance`, and the
    `balance_append` theorem.
  - `Hold.lean` — the `credit_holds` lifecycle (`HoldStep`, `Settlement`).
  - `Idempotency.lean` — `IdempotencyKey`.
  - `Sql/Reserve.lean` — the atomic conditional-insert statement that makes
    hold creation race-free.
  - `Sql/Migrate.lean` — applies `sql/*.sql` in order.
  - `Sweeper.lean` — the periodic job that releases expired holds.
- `LedgerTests/` — mirrors `Ledger/` 1:1 with `#guard`-based tests.
- `sql/` — the Postgres schema, as numbered migration files.
- `Main.lean` — the `ledger` executable: `lake exe ledger migrate` applies
  migrations; `lake exe ledger` (no args) runs the sweeper loop.

`broker` and `core` talk to Postgres directly for the request-path
operations (reserve/settle/record usage) — this service's only running
process is the background sweeper.

## Building

```
lake build            # library + `ledger` executable
lake build LedgerTests
```

Requires `libpq`/`pkg-config` (`brew install libpq pkg-config` on macOS,
`apt-get install libpq-dev pkg-config` on Debian/Ubuntu) — `linen`'s
Postgres FFI links against `libpq`.

## Running

```
DATABASE_URL=postgres://... lake exe ledger migrate   # apply sql/*.sql
DATABASE_URL=postgres://... lake exe ledger           # run the sweeper
```

`LEDGER_SWEEP_INTERVAL_SECONDS` (default `60`) sets the sweep interval.

## Container

CI publishes `ghcr.io/typednotes/ledger` on every push to `main` (`edge`)
and on `v*.*.*` tags (matching semver + `latest`). See
`.github/workflows/docker-publish.yml` and `Dockerfile`.
