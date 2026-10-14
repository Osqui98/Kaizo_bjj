-- ════════════════════════════════════════════════════════════════
-- FASE 3 · ROLLBACK DE EMERGENCIA
-- Si después de la Parte B algo deja de funcionar y hay que volver
-- rápido a como estaba (acceso abierto), correr esto.
-- Las funciones de la Parte A pueden quedar: no molestan.
-- ════════════════════════════════════════════════════════════════
do $$
declare t text;
begin
  foreach t in array array['alumnos','asistencia','graduaciones','torneos','torneos_participantes',
                           'config_clases','config_turnos','config_cinturones']
  loop
    execute format('create policy "rollback abierto" on public.%I for all to anon, authenticated
                    using (true) with check (true)', t);
  end loop;
end $$;
