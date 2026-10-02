# Ledger v0.3.7

Append-only migration `sql/0003_tenant_deletion.sql` aligns billing references
with core's explicit org/account deletion flow:

- `usage_events`, `credit_ledger` and `credit_holds` cascade with their org.
- Usage actor references become null when that account is removed from a
  surviving org; its billing history remains.
- Ledger usage-event references become null if the referenced event disappears.

No hold arithmetic, grant idempotency or SQL settlement wire changes. The embedded
`Ledger.Sql.history` and its Lean tests include the third migration. Referential
actions are PostgreSQL's trusted execution boundary, not a Lean cascade proof.
The app's real HTTP/browser/SQL fixture exercises all three histories, the former
restrictive-FK failure, account cleanup and preservation of other-owner billing.

Coordinate with app v0.9.1 (migration 0012) and fleet v0.6.2, publishing source
tags before manual fleet Plan/Apply. Existing migrations/tags remain immutable.
