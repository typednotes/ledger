-- Ledger schema, verbatim from typednotes/typednotes docs/services/ledger.md §4.
-- References `orgs`/`users`, which are owned by `core` (docs/services/core.md).

create table usage_events (
    id              uuid primary key default gen_random_uuid(),
    org_id          uuid not null references orgs(id),
    user_id         uuid references users(id),      -- null for org-level system usage
    run_id          uuid,
    event_type      text not null,                  -- 'inference' | 'egress' | ...
    provider        text not null,                  -- 'mistral' | 'baseten' | 'notion'
    model           text,
    input_tokens    bigint,
    output_tokens   bigint,
    cost_micros     bigint not null default 0,      -- what WE paid
    price_micros    bigint not null default 0,      -- what we CHARGED
    credits         bigint not null default 0,      -- billing unit
    idempotency_key text not null,
    occurred_at     timestamptz not null default now(),
    unique (idempotency_key)
);

create index on usage_events (org_id, occurred_at);
create index on usage_events (run_id);

-- Append-only. Balance is derived, never stored.
create table credit_ledger (
    id          uuid primary key default gen_random_uuid(),
    org_id      uuid not null references orgs(id),
    delta       bigint not null,               -- sign set by `reason`
    reason      text not null,
    run_id      uuid,
    usage_event uuid references usage_events(id),
    created_at  timestamptz not null default now()
);

create index on credit_ledger (org_id, created_at);

-- In-flight holds, so concurrent runs cannot each spend the same balance.
create table credit_holds (
    id         uuid primary key default gen_random_uuid(),
    org_id     uuid not null references orgs(id),
    run_id     uuid not null,
    amount     bigint not null,
    state      text not null check (state in ('held','settled','released')),
    created_at timestamptz not null default now(),
    expires_at timestamptz not null
);

create index on credit_holds (org_id) where state = 'held';
