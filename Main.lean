import Ledger
import Linen.Network.WebApp.Server
import Std.Sync.CancellationToken

open Database.SQL.Pool
open Database.SQL.Connection

/-- Build pool settings from `DATABASE_URL` (libpq connection string or
    URI), the same variable name `secrets-server` uses for its own
    Postgres connection. -/
def poolSettings : IO PoolSettings := do
  let url ← match ← IO.getEnv "DATABASE_URL" with
    | some url => pure url
    | none => throw (IO.userError "DATABASE_URL is not set")
  if h : url.length > 0 then
    pure { connSettings := Settings.uri url h }
  else
    throw (IO.userError "DATABASE_URL is empty")

/-- Sweep interval in seconds, defaulting to 60; see `Ledger.runSweeper`. -/
def sweepIntervalSeconds : IO Nat := do
  match ← IO.getEnv "LEDGER_SWEEP_INTERVAL_SECONDS" with
  | some s => match s.toNat? with
    | some n => pure n
    | none => throw (IO.userError s!"LEDGER_SWEEP_INTERVAL_SECONDS is not a number: {s}")
  | none => pure 60

/-- The port `/health` listens on: `PORT`, which Scaleway Serverless
    Containers set to the container's declared port, defaulting to 8080. -/
def healthPort : IO UInt16 := do
  match ← IO.getEnv "PORT" with
  | some s => match s.toNat? with
    | some n => if n < 65536 then pure n.toUInt16 else
        throw (IO.userError s!"PORT is out of range: {s}")
    | none => throw (IO.userError s!"PORT is not a number: {s}")
  | none => pure 8080

/-- `ledger` (no arguments): run the sweeper in a dedicated task and serve
    `GET /health` on `PORT`, reporting `503` once the sweeper task has
    stopped (see `Ledger.Health`). `ledger migrate`: apply the embedded
    history to a fresh local database (production uses `typednotes-infra`
    instead — see `Ledger.Sql.Migrate`). -/
def main (args : List String) : IO Unit := do
  let settings ← poolSettings
  let pool ← Pool.create settings
  match args with
  | ["migrate"] =>
    Ledger.Sql.migrate pool
  | [] =>
    let interval ← sweepIntervalSeconds
    let port ← healthPort
    let token ← Std.CancellationToken.new
    IO.println s!"ledger sweeper starting, interval={interval}s"
    let sweeper ← IO.asTask (prio := .dedicated) (Ledger.runSweeper pool interval token)
    IO.println s!"ledger /health listening on :{port}"
    Network.WebApp.Server.run port
      (Ledger.Health.application (return !(← IO.hasFinished sweeper)))
  | _ =>
    throw (IO.userError s!"usage: ledger [migrate]")
