<p align="center">
  <img src="logo.svg" alt="ledger" width="180">
</p>

<h1 align="center">ledger</h1>

<p align="center">
  <em>A usage ledger in Lean 4: the arithmetic and the hold lifecycle proven in Lean, the concurrency enforced by Postgres.</em>
</p>

<p align="center">
  <a href="https://github.com/typednotes/ledger/actions/workflows/lean_action_ci.yml"><img src="https://github.com/typednotes/ledger/actions/workflows/lean_action_ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/typednotes/ledger/actions/workflows/docker-publish.yml"><img src="https://github.com/typednotes/ledger/actions/workflows/docker-publish.yml/badge.svg" alt="Docker publish"></a>
  <a href="https://github.com/typednotes/ledger/pkgs/container/ledger"><img src="https://img.shields.io/badge/ghcr.io-typednotes%2Fledger-blue?logo=docker" alt="Docker image"></a>
  <a href="https://github.com/typednotes/ledger/tags"><img src="https://img.shields.io/github/v/tag/typednotes/ledger?label=version&sort=semver" alt="Version"></a>
  <a href="https://lean-lang.org/"><img src="https://img.shields.io/badge/Lean-v4.34.0-blue" alt="Lean v4.34.0"></a>
  <a href="https://github.com/typednotes/linen"><img src="https://img.shields.io/badge/built%20on-linen%20v1.5.0-c9b896" alt="Built on linen v1.5.0"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" alt="License: Apache 2.0"></a>
</p>

---

`ledger` is the `typednotes` usage-ledger service. It records
`usage_events`, holds a `credit_ledger` balance bounded by `credit_holds`
(credited by idempotent grants, keyed on `credit_ledger.idempotency_key`),
and proves the arithmetic and the hold lifecycle sound in Lean — Postgres
itself enforces the one property Lean types cannot: that two concurrent holds
can never together overspend a balance. It implements the service described
in [`typednotes/typednotes`](https://github.com/typednotes/typednotes)'s
`docs/services/ledger.md`, and is built on
[`linen`](https://github.com/typednotes/linen).

> Lean makes the arithmetic and the lifecycle correct. Postgres makes the
> concurrency correct.

## Table of contents

- [Features](#features)
- [How it fits together](#how-it-fits-together)
- [Quick start](#quick-start)
- [Configuration](#configuration)
- [HTTP API](#http-api)
- [Database schema](#database-schema)
- [Project layout](#project-layout)
- [Docker](#docker)
- [License](#license)

## Features

- **Proven balance arithmetic** — `Credits := Nat`, `Micros := Int`, the
  `credit_ledger` row type with `balance`, and the `balance_append` theorem.
- **A typed hold lifecycle** — `HoldStep` and `Settlement` make an illegal
  transition (anything out of `.settled` or `.released`) unrepresentable.
- **Race-free reserves** — one atomic conditional insert, so Postgres, not
  application code, guarantees concurrent holds cannot overspend.
- **Idempotent grants** — `insert into credit_ledger ... on conflict
  (idempotency_key) do nothing`, with the welcome-grant key
  `welcome:{org_id}`; safe to retry.
- **The hold sweeper** — a cancellable background loop that releases expired
  holds, surviving a failed sweep by logging and retrying.
- **An honest health check** — `GET /health` is `200` while the sweeper runs
  and `503` once it has stopped.
- **Tested by construction** — `LedgerTests/` mirrors `Ledger/` 1:1 with
  `#guard` checks, so building it runs every test.

## How it fits together

`broker` and `core` talk to Postgres directly for the request-path operations
(reserve, settle, record usage), and the typednotes app issues the grant
statement from `Ledger.Sql.Grant` itself (the welcome grant on org creation,
retried safely thanks to its idempotency key). The app cannot import Lean, so
the literal SQL text is the contract (`docs/connections.md` §6 in
`typednotes/typednotes`), pinned by `LedgerTests/Ledger/Sql/GrantTest.lean`.

This service's only runtime work is therefore the background sweeper. It
still listens on a port, because a Scaleway Serverless Container is not
considered started until something does, and it is deployed with
`minScale := 1` so scale-to-zero cannot stop the sweeper.

## Quick start

### Build

```sh
lake build            # the Ledger library
lake build ledger     # the `ledger` executable
```

Requires `libpq` and `pkg-config` — `linen`'s Postgres FFI links against
`libpq` (`brew install libpq pkg-config` on macOS,
`apt-get install libpq-dev pkg-config` on Debian/Ubuntu).

### Test

```sh
lake build LedgerTests
```

### Run

```sh
DATABASE_URL=postgres://... lake exe ledger migrate   # apply the history to a fresh DB
DATABASE_URL=postgres://... lake exe ledger           # sweeper + /health
```

The schema references `core`'s `orgs` and `users`
(`docs/services/core.md` in `typednotes/typednotes`), so those tables must
exist first.

## Configuration

| Variable | Required | Notes |
|---|---|---|
| `DATABASE_URL` | yes | Postgres connection string or URI |
| `LEDGER_SWEEP_INTERVAL_SECONDS` | no | sweep interval, default `60` |
| `PORT` | no | `/health` port, default `8080` (Scaleway sets it to the declared port) |

## HTTP API

- `GET /health` → `200 ok` while the sweeper task is running, `503` once it
  has stopped — so a container whose sweeper has died is restarted rather
  than kept looking healthy while expired holds are never released.

Everything else is `404`.

## Database schema

The schema lives in [`sql/`](sql) as numbered migration files — the only
copy of it:

| File | Adds |
|---|---|
| [`0001_init.sql`](sql/0001_init.sql) | `usage_events`, `credit_ledger`, `credit_holds` |
| [`0002_credit_ledger_idempotency.sql`](sql/0002_credit_ledger_idempotency.sql) | `credit_ledger.idempotency_key text unique` — nullable, so rows without a key (such as usage entries) are unaffected; the conflict target of grants |

**In production**, `typednotes-infra` reads `sql/*.sql` from GitHub at the
release tag and declares it as a `postgresMigrations` history: the plan names
the pending work, and the apply runs it before the `ledger` container rolls
out — after the app's history, which infra infers from `references orgs(id)`.
The container's own database identity has no DDL rights.

**Locally**, `lake exe ledger migrate` applies the same files, embedded with
`include_str` by `Ledger.Sql.history`.

To add a migration: add `sql/NNNN_description.sql` and its line in
`Ledger.Sql.history`, tag the release, then in `typednotes-infra` bump
ledger's release version and add the file to its history. Shipped migrations
are append-only — never edit one.

## Project layout

| Path | Contents |
|---|---|
| [`Ledger/Credits.lean`](Ledger/Credits.lean) | `Credits := Nat`, `Micros := Int` |
| [`Ledger/Ids.lean`](Ledger/Ids.lean) | foreign-key wrapper types owned by other services |
| [`Ledger/Entry.lean`](Ledger/Entry.lean) | the `credit_ledger` row type, `balance`, `balance_append` |
| [`Ledger/Hold.lean`](Ledger/Hold.lean) | the `credit_holds` lifecycle (`HoldStep`, `Settlement`) |
| [`Ledger/Idempotency.lean`](Ledger/Idempotency.lean) | `IdempotencyKey` |
| [`Ledger/Sql/Reserve.lean`](Ledger/Sql/Reserve.lean) | the atomic conditional insert that makes hold creation race-free |
| [`Ledger/Sql/Grant.lean`](Ledger/Sql/Grant.lean) | the idempotent grant statement and the `welcome:{org_id}` key |
| [`Ledger/Sql/History.lean`](Ledger/Sql/History.lean) | `sql/` embedded with `include_str` |
| [`Ledger/Sql/Migrate.lean`](Ledger/Sql/Migrate.lean) | applies the history to a fresh local database |
| [`Ledger/Sweeper.lean`](Ledger/Sweeper.lean) | the periodic job that releases expired holds |
| [`Ledger/Health.lean`](Ledger/Health.lean) | `GET /health` |
| [`LedgerTests/`](LedgerTests) | mirrors `Ledger/` 1:1 with `#guard`-based tests |
| [`Main.lean`](Main.lean) | the `ledger` executable (`ledger` / `ledger migrate`) |

See [`AGENTS.md`](AGENTS.md) for the coding conventions.

## Docker

Images are published to `ghcr.io/typednotes/ledger` — `edge` from `main`,
and `latest`, `X.Y.Z` and `X.Y` from release tags.

```sh
docker run --rm -p 8080:8080 -e DATABASE_URL=... ghcr.io/typednotes/ledger:latest
docker run --rm -e DATABASE_URL=... ghcr.io/typednotes/ledger:latest migrate
```

To build the image locally:

```sh
docker build -t ledger .
```

## License

Licensed under the [Apache License, Version 2.0](LICENSE).
