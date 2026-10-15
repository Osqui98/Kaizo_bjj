-- ════════════════════════════════════════════════════════════════
-- ESTADOS DEL ALUMNO + BLOQUEO + ELIMINAR
-- Correr ANTES de publicar el admin/index que usan estas columnas.
--
--   · estado: activo | lesionado | discontinuado  (lo médico/asistencia)
--   · bloqueado + motivo_bloqueo: independiente del estado (ej. pagos).
--     Bloqueado no puede marcar asistencia; el motivo solo lo ve el profe.
--   · Discontinuado puede marcar, pero sigue gris hasta que lo reactiven.
--   · admin_eliminar_alumno: borrado definitivo, solo profes.
-- ════════════════════════════════════════════════════════════════

-- 1. Columnas nuevas
alter table public.alumnos
  add column if not exists bloqueado boolean not null default false,
  add column if not exists motivo_bloqueo text;

-- 2. Unificar estados viejos: Inactivo, Baja y la casilla "Activo" destildada
--    pasan a Discontinuado (siguen en la lista, en gris, con su historial).
alter table public.alumnos drop constraint if exists alumnos_estado_check;
update public.alumnos set estado = 'discontinuado'
  where estado in ('inactivo','baja') or activo is not true;
update public.alumnos set estado = 'activo' where estado is null or estado = '';
update public.alumnos set activo = true where activo is not true;

-- 3. Lo que ve la pantalla de Asistencia de un alumno (sin foto, notas ni motivo)
create or replace function public.kiosco_publico(a public.alumnos)
returns jsonb
language sql immutable set search_path = public
as $$
  select to_jsonb(a) - array['foto_url','notas','motivo_bloqueo'];
$$;

create or replace function public.kiosco_buscar_alumno(p_dni text)
returns jsonb
language sql stable security definer set search_path = public
as $$
  select public.kiosco_publico(a)
  from public.alumnos a
  where a.dni = p_dni and a.activo
  limit 1;
$$;

create or replace function public.kiosco_registrar_alumno(p_datos jsonb)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  d public.alumnos;
  r public.alumnos;
begin
  d := jsonb_populate_record(null::public.alumnos, p_datos);
  insert into public.alumnos (nombre, apellido, dni, fecha_nac, sexo, cinturon, stripes, activo, estado)
  values (d.nombre, d.apellido, d.dni, d.fecha_nac, d.sexo, 'blanco', 0, true, 'activo')
  returning * into r;
  return public.kiosco_publico(r);
end;
$$;

create or replace function public.kiosco_actualizar_alumno(p_id bigint, p_dni text, p_datos jsonb)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  permitidos text[] := array[
    'nombre','apellido','fecha_nac','sexo','telefono','email','domicilio','instagram',
    'emerg_nombre','emerg_relacion','emerg_telefono','apto_fisico','apto_vencimiento',
    'es_competidor','peso','altura','tutor_nombre','tutor_relacion','tutor_telefono',
    'tutor_email','foto_url'];
  actual public.alumnos;
  n public.alumnos;
  datos jsonb;
begin
  select * into actual from public.alumnos where id = p_id and dni = p_dni and activo;
  if not found then
    raise exception 'Alumno no encontrado' using errcode = 'P0002';
  end if;
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) into datos
  from jsonb_each(p_datos) where key = any(permitidos);
  if length(datos ->> 'foto_url') > 300000 then
    raise exception 'La foto es demasiado grande' using errcode = '22001';
  end if;
  n := jsonb_populate_record(actual, datos);
  update public.alumnos set
    nombre = n.nombre, apellido = n.apellido, fecha_nac = n.fecha_nac, sexo = n.sexo,
    telefono = n.telefono, email = n.email, domicilio = n.domicilio, instagram = n.instagram,
    emerg_nombre = n.emerg_nombre, emerg_relacion = n.emerg_relacion, emerg_telefono = n.emerg_telefono,
    apto_fisico = n.apto_fisico, apto_vencimiento = n.apto_vencimiento, es_competidor = n.es_competidor,
    peso = n.peso, altura = n.altura,
    tutor_nombre = n.tutor_nombre, tutor_relacion = n.tutor_relacion,
    tutor_telefono = n.tutor_telefono, tutor_email = n.tutor_email,
    foto_url = n.foto_url
  where id = p_id;
  return public.kiosco_publico(n);
end;
$$;

-- 4. Marcar asistencia: un alumno bloqueado no puede
create or replace function public.kiosco_marcar_asistencia(p_alumno_id bigint, p_dni text, p_datos jsonb)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  a public.alumnos;
  d public.asistencia;
begin
  select * into a from public.alumnos where id = p_alumno_id and dni = p_dni and activo;
  if not found then
    raise exception 'Alumno no encontrado' using errcode = 'P0002';
  end if;
  if a.bloqueado then
    raise exception 'BLOQUEADO' using errcode = 'P0001';
  end if;
  d := jsonb_populate_record(null::public.asistencia, p_datos);
  insert into public.asistencia
    (alumno_id, nombre, apellido, fecha, turno, horario, tarde, motivo_tarde, con_fisico, "timestamp")
  values
    (a.id, a.nombre, a.apellido, d.fecha, d.turno, d.horario, d.tarde, d.motivo_tarde, d.con_fisico, d."timestamp");
end;
$$;

-- 5. Eliminar un alumno y todo su historial (solo profes autorizados)
create or replace function public.admin_eliminar_alumno(p_id bigint)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.es_admin() then
    raise exception 'No autorizado' using errcode = '42501';
  end if;
  delete from public.torneos_participantes where alumno_id = p_id;
  delete from public.graduaciones          where alumno_id = p_id;
  delete from public.asistencia            where alumno_id = p_id;
  delete from public.alumnos               where id = p_id;
  if not found then
    raise exception 'Alumno no encontrado' using errcode = 'P0002';
  end if;
end;
$$;
revoke execute on function public.admin_eliminar_alumno(bigint) from public, anon;
grant execute on function public.admin_eliminar_alumno(bigint) to authenticated;
