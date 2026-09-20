-- Fase 2: operadores, auditoria e painel administrativo
-- Execute no mesmo projeto Supabase da Central.
create table if not exists public.whatsapp_operators (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete cascade,
  display_name text not null,
  phone_label text,
  role text not null default 'operator' check (role in ('admin','operator')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.whatsapp_activity (
  id bigint generated always as identity primary key,
  operator_id uuid not null references public.whatsapp_operators(id),
  contact_key text not null,
  action text not null check (action in ('sent_confirmed','skipped','do_not_contact','opened')),
  created_at timestamptz not null default now()
);
create index if not exists whatsapp_activity_operator_date_idx on public.whatsapp_activity(operator_id,created_at desc);

alter table public.whatsapp_operators enable row level security;
alter table public.whatsapp_activity enable row level security;

create or replace function public.is_whatsapp_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.whatsapp_operators where user_id=auth.uid() and role='admin' and active=true); $$;

create policy "operator_read_self_or_admin" on public.whatsapp_operators
for select to authenticated using (user_id=auth.uid() or public.is_whatsapp_admin());

create policy "admin_manage_operators" on public.whatsapp_operators
for all to authenticated using (public.is_whatsapp_admin()) with check (public.is_whatsapp_admin());

create policy "activity_read_self_or_admin" on public.whatsapp_activity
for select to authenticated using (
  public.is_whatsapp_admin() or operator_id in (select id from public.whatsapp_operators where user_id=auth.uid() and active=true)
);

create policy "activity_insert_self" on public.whatsapp_activity
for insert to authenticated with check (
  operator_id in (select id from public.whatsapp_operators where user_id=auth.uid() and active=true)
);

create or replace view public.whatsapp_daily_operator_summary
with (security_invoker=true) as
select o.id operator_id,o.display_name,o.phone_label,
       (a.created_at at time zone 'America/Sao_Paulo')::date activity_date,
       count(*) filter (where a.action='sent_confirmed') sent_confirmed,
       count(*) filter (where a.action='skipped') skipped,
       count(*) filter (where a.action='do_not_contact') do_not_contact,
       max(a.created_at) last_activity
from public.whatsapp_operators o
left join public.whatsapp_activity a on a.operator_id=o.id
group by o.id,o.display_name,o.phone_label,(a.created_at at time zone 'America/Sao_Paulo')::date;

grant select on public.whatsapp_daily_operator_summary to authenticated;
