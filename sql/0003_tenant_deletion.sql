-- Core explicitly deletes an organization and its billing data together.
-- Account deletion retains surviving orgs' usage but removes the actor pointer.
alter table usage_events drop constraint usage_events_org_id_fkey;
alter table usage_events add constraint usage_events_org_id_fkey
    foreign key (org_id) references orgs(id) on delete cascade;
alter table credit_ledger drop constraint credit_ledger_org_id_fkey;
alter table credit_ledger add constraint credit_ledger_org_id_fkey
    foreign key (org_id) references orgs(id) on delete cascade;
alter table credit_holds drop constraint credit_holds_org_id_fkey;
alter table credit_holds add constraint credit_holds_org_id_fkey
    foreign key (org_id) references orgs(id) on delete cascade;
alter table usage_events drop constraint usage_events_user_id_fkey;
alter table usage_events add constraint usage_events_user_id_fkey
    foreign key (user_id) references users(id) on delete set null;
alter table credit_ledger drop constraint credit_ledger_usage_event_fkey;
alter table credit_ledger add constraint credit_ledger_usage_event_fkey
    foreign key (usage_event) references usage_events(id) on delete set null;
