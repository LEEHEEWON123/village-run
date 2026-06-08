-- supabase/migrations/003_functions.sql

create or replace function upsert_user_territory(
  p_user_id uuid,
  p_new_territory text,
  p_new_area float
) returns void language plpgsql security definer as $$
declare
  v_new_geom geometry := ST_GeomFromGeoJSON(p_new_territory);
  v_existing geometry;
begin
  select merged_territory into v_existing
  from public.user_territory
  where user_id = p_user_id;

  if v_existing is null then
    insert into public.user_territory (user_id, total_area_m2, merged_territory)
    values (p_user_id, p_new_area, v_new_geom);
  else
    update public.user_territory
    set
      merged_territory = ST_Union(v_existing, v_new_geom),
      total_area_m2 = total_area_m2 + p_new_area,
      updated_at = now()
    where user_id = p_user_id;
  end if;
end;
$$;
