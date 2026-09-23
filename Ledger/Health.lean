/-
  Ledger.Health — the one HTTP route this service serves

  `ledger`'s only real work is the background sweeper (`Ledger.Sweeper`);
  nothing calls it over the network. It serves HTTP anyway because its
  deploy target requires it: a Scaleway Serverless Container is only
  considered started once something listens on its port, so a process that
  never binds one never finishes deploying.

  The route answers `GET /health`, and it answers **honestly**: `200` while
  the sweeper task is still running, `503` once it has stopped. A health
  check that returned `200` regardless would keep a container whose sweeper
  had died looking healthy for ever — expired holds never released, and the
  org's spendable balance slowly shrinking with no signal anywhere. (The
  sweeper already survives a failed sweep by logging and retrying; `503`
  covers what that loop cannot, the task itself ending.)

  The container is deployed with `minScale := 1` for the same reason:
  scale-to-zero would stop the sweeper whenever nobody polled `/health`.
-/

import Linen.Network.WebApp

namespace Ledger.Health

open Network.HTTP.Types

/-- What a request to `path` with `method` gets, given whether the sweeper
    is still running: `some true` → `200`, `some false` → `503`, `none` →
    `404`. Pure, so the routing rule is testable without a socket. -/
def verdict (method : Method) (path : String) (sweeperRunning : Bool) : Option Bool :=
  if path == "/health" && method == .standard .GET then some sweeperRunning else none

/-- The `ledger` `Application`: `GET /health`, and nothing else.
    `sweeperRunning` is asked per request, so the answer is current. -/
def application (sweeperRunning : IO Bool) : Network.WebApp.Application :=
  fun req respond =>
    Network.WebApp.AppM.respondIO respond do
      match verdict req.requestMethod req.rawPathInfo (← sweeperRunning) with
      | some true  => return Network.WebApp.responseLBS status200 [] "ok"
      | some false => return Network.WebApp.responseLBS status503 [] "sweeper stopped"
      | none       => return Network.WebApp.responseLBS status404 [] "not found"

end Ledger.Health
