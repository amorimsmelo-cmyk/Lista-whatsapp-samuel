-- Central Samuel: estado operacional compartilhado entre aparelhos
create table if not exists public.whatsapp_operation_state (
  id text primary key default 'main',
  message_draft text not null default '',
  batch_size integer not null default 10 check (batch_size in (10,12)),
  batch_keys jsonb not null default '[]'::jsonb,
  cursor integer not null default 0,
  next_review_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.whatsapp_contact_flags (
  contact_key text primary key,
  status text not null check (status in ('skipped','do_not_contact')),
  updated_at timestamptz not null default now()
);

alter table public.whatsapp_operation_state enable row level security;
alter table public.whatsapp_contact_flags enable row level security;

-- Mantém o mesmo modelo de acesso compartilhado já usado pela Central.
-- Revise estas políticas no painel do Supabase antes de produção.
create policy "central_read_operation_state" on public.whatsapp_operation_state for select to anon using (true);
create policy "central_insert_operation_state" on public.whatsapp_operation_state for insert to anon with check (id='main');
create policy "central_update_operation_state" on public.whatsapp_operation_state for update to anon using (id='main') with check (id='main');
create policy "central_read_contact_flags" on public.whatsapp_contact_flags for select to anon using (true);
create policy "central_insert_contact_flags" on public.whatsapp_contact_flags for insert to anon with check (true);
create policy "central_update_contact_flags" on public.whatsapp_contact_flags for update to anon using (true) with check (true);

insert into public.whatsapp_operation_state(id) values ('main') on conflict (id) do nothing;
