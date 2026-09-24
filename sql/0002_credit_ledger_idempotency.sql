-- Idempotent credit grants (typednotes/typednotes docs/connections.md §6).
-- Grants — e.g. the app's welcome grant on org creation — must be
-- idempotent: the app retries, and a double grant is free money. The grant
-- statement (Ledger/Sql/Grant.lean) keys on this column with
-- `on conflict (idempotency_key) do nothing`.
-- Nullable: unique treats NULLs as distinct, so existing rows and the usage
-- inserts that do not set a key are unaffected.

alter table credit_ledger add column idempotency_key text unique;
