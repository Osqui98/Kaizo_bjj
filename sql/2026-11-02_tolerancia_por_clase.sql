-- ════════════════════════════════════════════════════════════════
-- TOLERANCIA DE LLEGADA TARDE POR CLASE
--   Antes vivía en config_turnos (día y horario como texto) y el kiosco
--   la buscaba comparando textos: las clases nuevas no tenían fila y
--   usaban siempre 15 min. Ahora es una columna de cada clase.
--   Se copian los valores que ya estaban configurados.
--   config_turnos queda sin uso (no se borra).
-- Se pega todo junto en Supabase → SQL Editor → Run, ANTES del push.
-- ════════════════════════════════════════════════════════════════

alter table public.config_clases add column if not exists tolerancia_min integer not null default 15;

-- Copia lo configurado: mismo día de la semana y mismo horario "HH:MM - HH:MM"
update public.config_clases c
set tolerancia_min = t.tolerancia_min
from public.config_turnos t
where t.activo
  and t.tolerancia_min is not null
  and array_position(array['domingo','lunes','martes','miercoles','jueves','viernes','sabado'],
        lower(translate(trim(t.dia), 'áéíóúÁÉÍÓÚ', 'aeiouaeiou'))) - 1 = c.dia
  and replace(translate(t.horario, '–—', '--'), ' ', '')
      = left(c.hora_inicio::text, 5) || '-' || left(c.hora_fin::text, 5);

-- Para revisar: cada clase con su tolerancia
select dia, hora_inicio, hora_fin, nombre, tolerancia_min, activo
from public.config_clases order by activo desc, dia, hora_inicio;

notify pgrst, 'reload schema';
