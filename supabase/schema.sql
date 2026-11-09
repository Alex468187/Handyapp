-- Summer: Datenbank-Schema (Supabase / Postgres).
-- Alle Einträge (Termine, Aufgaben, Notizen) liegen in einer Tabelle.
-- Jede Zeile gehört einem angemeldeten Nutzer und ist nur für ihn sichtbar.

create table if not exists public.items (
  user_id    uuid        not null default auth.uid() references auth.users on delete cascade,
  id         text        not null,
  kind       text        not null check (kind in ('task', 'chore', 'note')),
  data       jsonb,
  deleted    boolean     not null default false,
  updated_at timestamptz not null default clock_timestamp(),
  primary key (user_id, id)
);

create index if not exists items_user_updated on public.items (user_id, updated_at);

-- Server-Zeitstempel bei jeder Änderung: danach holt sich die App Neues ab.
create or replace function public.items_touch() returns trigger
language plpgsql as $$
begin
  new.updated_at := clock_timestamp();
  return new;
end $$;

drop trigger if exists items_touch on public.items;
create trigger items_touch before insert or update on public.items
  for each row execute function public.items_touch();

alter table public.items enable row level security;

drop policy if exists items_own on public.items;
create policy items_own on public.items
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, insert, update, delete on public.items to authenticated;
