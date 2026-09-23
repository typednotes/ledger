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
  - `Sql/History.lean` — `sql/` embedded with `include_str`, for
    `Sql/Migrate.lean`, which applies it to a fresh local database.
  - `Sweeper.lean` — the periodic job that releases expired holds.
  - `Health.lean` — `GET /health`: `200` while the sweeper runs, `503` once
    it has stopped.
- `LedgerTests/` — mirrors `Ledger/` 1:1 with `#guard`-based tests.
- `sql/` — the Postgres schema, as numbered migration files.
- `Main.lean` — the `ledger` executable: `lake exe ledger migrate` applies
  migrations to a local database; `lake exe ledger` (no args) runs the
  sweeper loop in a background task and serves `/health` on `PORT`.

`broker` and `core` talk to Postgres directly for the request-path
operations (reserve/settle/record usage) — this service's only real work is
the background sweeper. It still listens on a port, because a Scaleway
Serverless Container is not considered started until something does, and
it is deployed with `minScale := 1` so scale-to-zero cannot stop the sweeper.

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
DATABASE_URL=postgres://... lake exe ledger migrate   # apply the history (fresh DB)
DATABASE_URL=postgres://... lake exe ledger           # sweeper + /health
```

`LEDGER_SWEEP_INTERVAL_SECONDS` (default `60`) sets the sweep interval;
`PORT` (default `8080`) the `/health` port.

The schema references `core`'s `orgs` and `users` (`docs/services/core.md`
in `typednotes/typednotes`), so those tables must exist first.

## Migrations in production

`typednotes-infra` reads `sql/*.sql` from GitHub at the release tag and
declares it as a `postgresMigrations` history: the plan names the pending
work, the apply runs it before the `ledger` container rolls out — after the
app's history, which infra infers from `references orgs(id)` — and the
container's own database identity has no DDL rights. To add a migration: add
`sql/NNNN_description.sql` (and its line in `Ledger.Sql.history`, for local
`migrate`), tag the release, then in `typednotes-infra` bump ledger's release
version and add the file to its history. Shipped migrations are append-only.

## Container

CI publishes `ghcr.io/typednotes/ledger` on every push to `main` (`edge`)
and on `v*.*.*` tags (matching semver + `latest`). See
`.github/workflows/docker-publish.yml` and `Dockerfile`.
