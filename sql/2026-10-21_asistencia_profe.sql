-- ════════════════════════════════════════════════════════════════
-- ASISTENCIA CARGADA POR EL PROFE + TOTALES POR ALUMNO
--   · asistencia.cargada_por: null = la marcó el alumno en el kiosco,
--     'profe' = la cargó el profe a mano desde la ficha del alumno.
--   · admin_totales_asistencia(): clases en total de cada alumno, ya
--     contadas en la base (para la lista de Alumnos del panel).
--   · kiosco_stats(): ahora con la fecha de Argentina.
-- El panel funciona sin esto, pero sin el total y sin la etiqueta "a mano".
-- Se pega todo junto en Supabase → SQL Editor → Run.
-- ════════════════════════════════════════════════════════════════

alter table public.asistencia add column if not exists cargada_por text;

-- Corre con los permisos de quien la llama: solo los profes ven datos
create or replace function public.admin_totales_asistencia()
returns table(alumno_id bigint, total bigint)
language sql stable security invoker set search_path = public
as $$
  select s.alumno_id::bigint, count(*)
  from public.asistencia s
  where s.alumno_id is not null and public.es_admin()
  group by s.alumno_id;
$$;

-- ════════════════════════════════════════════════════════════════
-- kiosco_stats con la fecha de Argentina (antes usaba la del servidor,
-- en UTC: desde las 21 h el último día del mes "Este mes" daba 0, y el
-- domingo a la noche la racha de semanas arrancaba de cero).
-- ════════════════════════════════════════════════════════════════
create or replace function public.kiosco_stats(p_id bigint, p_dni text)
returns jsonb
language sql stable security definer set search_path = public
as $$
  with hoy as (
    select (now() at time zone 'America/Argentina/Buenos_Aires')::date as d
  ), a as (
    select id from public.alumnos where id = p_id and dni = p_dni and activo
  ), f as (
    select s.fecha::date as d from public.asistencia s join a on a.id = s.alumno_id
  ), sem as (
    select distinct date_trunc('week', d)::date as w from f
  ), ord as (
    select w, row_number() over (order by w desc) as n from sem
  )
  select case when not exists (select 1 from a) then null else jsonb_build_object(
    'mes',   (select count(*) from f, hoy where f.d >= date_trunc('month', hoy.d)::date),
    'total', (select count(*) from f),
    'racha', (select count(*) from ord, hoy
              where w = (date_trunc('week', hoy.d)::date - ((n - 1) * 7)::int))
  ) end;
$$;

-- Que el panel y el kiosco vean los cambios enseguida
notify pgrst, 'reload schema';
