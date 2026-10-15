-- ════════════════════════════════════════════════════════════════
-- CATEGORÍAS (Kinder / Infantil / Adulto) + CINTURONES INFANTILES
-- Correr ANTES de publicar el admin/index que usan estas columnas.
--
--   · alumnos.categoria: la asigna el profe a mano. Esta migración la
--     completa UNA SOLA VEZ por edad; después nunca se recalcula.
--   · config_clases.categoria: a qué grupo pertenece cada clase.
--   · asistencia.categoria: el grupo de la clase en la que marcó.
-- ════════════════════════════════════════════════════════════════

-- 1. Columnas
alter table public.alumnos       add column if not exists categoria text;
alter table public.config_clases add column if not exists categoria text not null default 'adulto';
alter table public.asistencia    add column if not exists categoria text;

alter table public.alumnos drop constraint if exists alumnos_cinturon_check;  -- por si limitaba a los cinturones de adultos
alter table public.alumnos drop constraint if exists alumnos_categoria_check;
alter table public.alumnos add constraint alumnos_categoria_check
  check (categoria is null or categoria in ('kinder','infantil','adulto'));
alter table public.config_clases drop constraint if exists config_clases_categoria_check;
alter table public.config_clases add constraint config_clases_categoria_check
  check (categoria in ('kinder','infantil','adulto'));

-- 2. Carga inicial por edad (una sola vez): <7 Kinder, 7–12 Infantil, resto Adulto
update public.alumnos set categoria = case
    when fecha_nac is not null and extract(year from age(current_date, fecha_nac)) < 7  then 'kinder'
    when fecha_nac is not null and extract(year from age(current_date, fecha_nac)) < 13 then 'infantil'
    else 'adulto' end
  where categoria is null;

-- Las clases y asistencias que ya existen son de adultos
update public.asistencia set categoria = 'adulto' where categoria is null;

-- 3. Cinturones infantiles (IBJJF kids) y orden general
insert into public.config_cinturones (cinturon, max_stripes, orden)
select v.c, 4, v.o from (values ('gris',2),('amarillo',3),('naranja',4),('verde',5)) v(c,o)
where not exists (select 1 from public.config_cinturones x where x.cinturon = v.c);
update public.config_cinturones set orden = case cinturon
  when 'blanco' then 1 when 'gris' then 2 when 'amarillo' then 3 when 'naranja' then 4 when 'verde' then 5
  when 'azul' then 6 when 'violeta' then 7 when 'marron' then 8 when 'negro' then 9 else orden end;

-- 4. Registro desde Asistencia: guarda tutor y la categoría de la clase en curso
create or replace function public.kiosco_registrar_alumno(p_datos jsonb)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  d public.alumnos;
  r public.alumnos;
  cat text := p_datos ->> 'categoria';
begin
  d := jsonb_populate_record(null::public.alumnos, p_datos);
  if cat is not null and cat not in ('kinder','infantil','adulto') then cat := null; end if;
  insert into public.alumnos (nombre, apellido, dni, fecha_nac, sexo, cinturon, stripes, activo, estado, categoria,
                              tutor_nombre, tutor_relacion, tutor_telefono, tutor_email)
  values (d.nombre, d.apellido, d.dni, d.fecha_nac, d.sexo, 'blanco', 0, true, 'activo', cat,
          d.tutor_nombre, d.tutor_relacion, d.tutor_telefono, d.tutor_email)
  returning * into r;
  return public.kiosco_publico(r);
end;
$$;

-- 5. Marcar asistencia: guarda la categoría de la clase
create or replace function public.kiosco_marcar_asistencia(p_alumno_id bigint, p_dni text, p_datos jsonb)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  a public.alumnos;
  d public.asistencia;
  cat text := p_datos ->> 'categoria';
begin
  select * into a from public.alumnos where id = p_alumno_id and dni = p_dni and activo;
  if not found then
    raise exception 'Alumno no encontrado' using errcode = 'P0002';
  end if;
  if a.bloqueado then
    raise exception 'BLOQUEADO' using errcode = 'P0001';
  end if;
  if cat is null or cat not in ('kinder','infantil','adulto') then cat := coalesce(a.categoria, 'adulto'); end if;
  d := jsonb_populate_record(null::public.asistencia, p_datos);
  insert into public.asistencia
    (alumno_id, nombre, apellido, fecha, turno, horario, tarde, motivo_tarde, con_fisico, "timestamp", categoria)
  values
    (a.id, a.nombre, a.apellido, d.fecha, d.turno, d.horario, d.tarde, d.motivo_tarde, d.con_fisico, d."timestamp", cat);
end;
$$;
