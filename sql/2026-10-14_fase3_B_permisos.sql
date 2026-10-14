-- ════════════════════════════════════════════════════════════════
-- FASE 3 · PARTE B — Cerrar el acceso público a los datos
-- Correr DESPUÉS de la Parte A y de publicar el index nuevo.
--
-- Resultado:
--   · Profes autorizados (login Google + admins_autorizados): acceso total.
--   · Público (clave anon): solo lee clases, turnos, cinturones y torneos,
--     y se inscribe en torneos. Alumnos y asistencia solo vía funciones
--     kiosco_* (que piden el DNI).
--   · Cualquier otra cuenta de Google logueada: nada.
-- ════════════════════════════════════════════════════════════════

-- 0. Seguro: si la Parte A no se corrió, frenar acá sin tocar nada
do $$
begin
  if to_regprocedure('public.es_admin()') is null
     or to_regprocedure('public.kiosco_marcar_asistencia(bigint,text,jsonb)') is null then
    raise exception 'Falta correr la Parte A (sql/2026-10-14_fase3_A_funciones.sql) antes que esta.';
  end if;
end $$;

-- 1. Borrar TODAS las políticas actuales de estas tablas
do $$
declare p record;
begin
  for p in
    select tablename, policyname from pg_policies
    where schemaname = 'public'
      and tablename in ('alumnos','asistencia','graduaciones','torneos','torneos_participantes',
                        'config_clases','config_turnos','config_cinturones')
  loop
    execute format('drop policy %I on public.%I', p.policyname, p.tablename);
  end loop;
end $$;

-- 2. RLS activado + acceso total para profes autorizados
do $$
declare t text;
begin
  foreach t in array array['alumnos','asistencia','graduaciones','torneos','torneos_participantes',
                           'config_clases','config_turnos','config_cinturones']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "profes todo" on public.%I for all to authenticated
                    using (public.es_admin()) with check (public.es_admin())', t);
  end loop;
end $$;

-- 3. Lectura pública de datos no sensibles
create policy "publico lee" on public.config_clases     for select to anon using (true);
create policy "publico lee" on public.config_turnos     for select to anon using (true);
create policy "publico lee" on public.config_cinturones for select to anon using (true);
create policy "publico lee" on public.torneos           for select to anon using (true);

-- 4. Torneos: el alumno ve inscripciones y se inscribe desde su ficha
create policy "publico lee"      on public.torneos_participantes for select to anon using (true);
create policy "alumno inscribe"  on public.torneos_participantes for insert to anon
  with check (cargado_por = 'alumno');
