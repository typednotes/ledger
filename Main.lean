import Ledger
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

def main (args : List String) : IO Unit := do
  let settings ← poolSettings
  let pool ← Pool.create settings
  match args with
  | ["migrate"] =>
    Ledger.Sql.migrate pool
  | [] =>
    let interval ← sweepIntervalSeconds
    let token ← Std.CancellationToken.new
    IO.println s!"ledger sweeper starting, interval={interval}s"
    Ledger.runSweeper pool interval token
  | _ =>
    throw (IO.userError s!"usage: ledger [migrate]")
