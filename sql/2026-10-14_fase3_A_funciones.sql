-- ════════════════════════════════════════════════════════════════
-- FASE 3 · PARTE A — Funciones para la pantalla de Asistencia
-- Solo AGREGA cosas: no cambia permisos ni rompe nada de lo actual.
-- Correr ANTES de publicar el index nuevo.
-- ════════════════════════════════════════════════════════════════

-- 1. Una sola asistencia por alumno, fecha y turno (evita duplicados en la base)
alter table public.asistencia
  add constraint asistencia_unica unique (alumno_id, fecha, turno);

-- 2. ¿El usuario logueado es un profe autorizado?
create or replace function public.es_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.admins_autorizados
    where email = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

-- 3. Buscar un alumno activo por DNI (sin la foto)
create or replace function public.kiosco_buscar_alumno(p_dni text)
returns jsonb
language sql stable security definer set search_path = public
as $$
  select to_jsonb(a) - 'foto_url'
  from public.alumnos a
  where a.dni = p_dni and a.activo
  limit 1;
$$;

-- 4. Foto de un alumno (requiere su DNI)
create or replace function public.kiosco_foto(p_id bigint, p_dni text)
returns text
language sql stable security definer set search_path = public
as $$
  select foto_url from public.alumnos
  where id = p_id and dni = p_dni and activo;
$$;

-- 5. ¿Ya marcó asistencia en esta clase hoy?
create or replace function public.kiosco_ya_registrado(p_alumno_id bigint, p_fecha text, p_turno text)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.asistencia
    where alumno_id = p_alumno_id and fecha::text = p_fecha and turno = p_turno
  );
$$;

-- 6. Registrar un alumno nuevo desde Asistencia
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
  return to_jsonb(r) - 'foto_url';
end;
$$;

-- 7. El alumno actualiza su ficha (solo estos campos, y solo con su DNI)
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
  return to_jsonb(n) - 'foto_url';
end;
$$;

-- 8. Marcar asistencia (requiere el DNI del alumno)
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
  d := jsonb_populate_record(null::public.asistencia, p_datos);
  insert into public.asistencia
    (alumno_id, nombre, apellido, fecha, turno, horario, tarde, motivo_tarde, con_fisico, "timestamp")
  values
    (a.id, a.nombre, a.apellido, d.fecha, d.turno, d.horario, d.tarde, d.motivo_tarde, d.con_fisico, d."timestamp");
end;
$$;
