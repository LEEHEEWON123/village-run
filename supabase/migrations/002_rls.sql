-- supabase/migrations/002_rls.sql

-- users RLS
alter table public.users enable row level security;

create policy "users: 본인만 수정" on public.users
  for all using (auth.uid() = id);

create policy "users: 누구나 읽기" on public.users
  for select using (true);

-- runs RLS
alter table public.runs enable row level security;

create policy "runs: 본인만 쓰기" on public.runs
  for all using (auth.uid() = user_id);

create policy "runs: 누구나 읽기" on public.runs
  for select using (true);

-- user_territory RLS
alter table public.user_territory enable row level security;

create policy "territory: 본인만 쓰기" on public.user_territory
  for all using (auth.uid() = user_id);

create policy "territory: 누구나 읽기" on public.user_territory
  for select using (true);
