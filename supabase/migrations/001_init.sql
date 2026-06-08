-- supabase/migrations/001_init.sql

-- PostGIS 확장 활성화
create extension if not exists postgis;

-- users 테이블 (Supabase auth.users 미러)
create table public.users (
  id           uuid primary key references auth.users(id) on delete cascade,
  email        text,
  display_name text,
  avatar_url   text,
  created_at   timestamptz default now()
);

-- runs 테이블
create table public.runs (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.users(id) on delete cascade,
  started_at        timestamptz not null,
  ended_at          timestamptz not null,
  distance_m        float not null default 0,
  area_m2           float not null default 0,
  path              jsonb not null default '[]',
  territory         geometry(Geometry, 4326),
  territory_geojson text,
  created_at        timestamptz default now()
);

-- user_territory 테이블 (누적 영역)
create table public.user_territory (
  user_id          uuid primary key references public.users(id) on delete cascade,
  total_area_m2    float not null default 0,
  merged_territory geometry(Geometry, 4326),
  updated_at       timestamptz default now()
);

-- 인덱스
create index runs_user_id_idx on public.runs(user_id);
create index runs_territory_idx on public.runs using gist(territory);
create index user_territory_idx on public.user_territory using gist(merged_territory);

-- auth.users 신규 가입 시 public.users 자동 생성 트리거
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.users (id, email, display_name, avatar_url)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
