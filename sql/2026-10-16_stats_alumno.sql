-- ════════════════════════════════════════════════════════════════
-- ESTADÍSTICAS DEL ALUMNO (pantalla "¡Oss!" al marcar asistencia)
--   · mes:   clases este mes
--   · racha: semanas seguidas (hasta la actual) con al menos una clase
--   · total: clases en total
-- Pide el DNI, igual que las demás funciones de Asistencia.
-- ════════════════════════════════════════════════════════════════
create or replace function public.kiosco_stats(p_id bigint, p_dni text)
returns jsonb
language sql stable security definer set search_path = public
as $$
  with a as (
    select id from public.alumnos where id = p_id and dni = p_dni and activo
  ), f as (
    select s.fecha::date as d from public.asistencia s join a on a.id = s.alumno_id
  ), sem as (
    select distinct date_trunc('week', d)::date as w from f
  ), ord as (
    select w, row_number() over (order by w desc) as n from sem
  )
  select case when not exists (select 1 from a) then null else jsonb_build_object(
    'mes',   (select count(*) from f where d >= date_trunc('month', current_date)::date),
    'total', (select count(*) from f),
    'racha', (select count(*) from ord
              where w = (date_trunc('week', current_date)::date - ((n - 1) * 7)::int))
  ) end;
$$;
