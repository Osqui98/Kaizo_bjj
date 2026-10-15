-- ════════════════════════════════════════════════════════════════
-- FICHA DEL ALUMNO (Asistencia → Ver / editar mi ficha)
-- El alumno puede editar todos sus datos MENOS: estado, bloqueo, notas,
-- DNI, categoría, cinturón/stripes/graduación y "es profe".
-- Suma turno y fecha de inicio a la lista de campos permitidos.
-- ════════════════════════════════════════════════════════════════
create or replace function public.kiosco_actualizar_alumno(p_id bigint, p_dni text, p_datos jsonb)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  permitidos text[] := array[
    'nombre','apellido','fecha_nac','sexo','turno','fecha_inicio',
    'telefono','email','domicilio','instagram',
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
  if coalesce(trim(n.nombre), '') = '' or coalesce(trim(n.apellido), '') = '' then
    raise exception 'Nombre y apellido son obligatorios' using errcode = '23502';
  end if;
  update public.alumnos set
    nombre = n.nombre, apellido = n.apellido, fecha_nac = n.fecha_nac, sexo = n.sexo,
    turno = n.turno, fecha_inicio = n.fecha_inicio,
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
