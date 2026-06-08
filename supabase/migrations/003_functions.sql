-- supabase/migrations/003_functions.sql

create or replace function upsert_user_territory(
  p_user_id uuid,
  p_new_territory text,
  p_new_area float
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_new_geom geometry := ST_GeomFromGeoJSON(p_new_territory);
begin
  if p_user_id <> auth.uid() then
    raise exception 'unauthorized';
  end if;

  insert into public.user_territory (user_id, total_area_m2, merged_territory, updated_at)
  values (p_user_id, p_new_area, v_new_geom, now())
  on conflict (user_id) do update set
    merged_territory = ST_Union(user_territory.merged_territory, excluded.merged_territory),
    total_area_m2    = user_territory.total_area_m2 + excluded.total_area_m2,
    updated_at       = now();
end;
$$;
