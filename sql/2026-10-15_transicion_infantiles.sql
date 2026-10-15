-- ════════════════════════════════════════════════════════════════
-- TRANSICIÓN hasta los horarios nuevos de noviembre
--   · Todos los chicos quedan como Infantil (los Kinders se separan después).
--   · Las clases de chicos actuales (martes y jueves 18–19) pasan a Infantil.
-- Los chicos nuevos que se registran desde Asistencia quedan "Sin categoría"
-- y pueden elegir cualquier clase hasta que el profe les asigne su grupo.
-- ════════════════════════════════════════════════════════════════
update public.alumnos      set categoria = 'infantil' where categoria = 'kinder';
update public.config_clases set categoria = 'infantil' where id in (10, 11);   -- "Bjj kids" (mar) y "Bjjkids" (jue)
