/-
  Ledger.Sweeper — release expired credit holds exactly once

  `services/ledger.md` §5, §7 (Tier 5): "expired holds swept by periodic
  job" is the one background process this service runs; every other
  operation (reserve, settle, record usage) is a single Postgres statement
  issued directly by `broker`/`core`, not something `ledger` serves over a
  network.

  `services/ledger.md` §2 lists `Control/Concurrent/Green` as a dependency
  for this sweeper, but `linen` already has an established idiom for
  exactly this shape of background job — `System.TimeManager`'s
  cooperative-cancellation `while` loop — and this sweeper is a single
  sequential poll with nothing to interleave concurrently, so it follows
  that idiom instead of pulling in the heavier `Green` monad. The loop
  terminates via `Std.CancellationToken`, never a fuel parameter, so it is
  not a `partial def`.

  The release itself is `update ... where state = 'held' and expires_at <
  now()`: an update's `WHERE` clause only ever matches rows still in
  `'held'`, so a hold already settled or released by a concurrent request
  is simply not touched — "exactly once" falls out of the `WHERE` clause,
  not out of any lock this module takes.
-/

import Linen.Database.SQL.Pool
import Std.Sync.CancellationToken

namespace Ledger

open Database.SQL.Pool
open Database.SQL.Session

/-- Release every `credit_holds` row that is still `'held'` past its
    `expires_at`. Idempotent: running it twice in a row releases nothing
    the second time, since the first run already moved those rows out of
    `'held'`. -/
def sweepExpiredHolds (pool : Pool) : IO (Except PoolError Unit) :=
  pool.use (Session.sql "
    update credit_holds
       set state = 'released'
     where state = 'held'
       and expires_at < now();
  ")

/-- Run `sweepExpiredHolds` every `intervalSeconds`, until `token` is
    cancelled. A failed sweep is logged and retried on the next tick rather
    than crashing the process — a transient Postgres hiccup should not take
    the sweeper down. -/
def runSweeper (pool : Pool) (intervalSeconds : Nat := 60)
    (token : Std.CancellationToken) : IO Unit := do
  while !(← token.isCancelled) do
    match ← sweepExpiredHolds pool with
    | .ok () => pure ()
    | .error e => IO.eprintln s!"sweep failed: {e}"
    IO.sleep (intervalSeconds * 1000).toUInt32

end Ledger
