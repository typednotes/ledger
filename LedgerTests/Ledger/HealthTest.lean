import Ledger.Health

open Ledger.Health
open Network.HTTP.Types

-- `GET /health` reports the sweeper: running → 200, stopped → 503.
#guard verdict (.standard .GET) "/health" true = some true
#guard verdict (.standard .GET) "/health" false = some false

-- Nothing else is served: other paths and other methods are 404, whatever
-- the sweeper is doing.
#guard verdict (.standard .GET) "/" true = none
#guard verdict (.standard .POST) "/health" true = none
#guard verdict (.standard .GET) "/health/" true = none
