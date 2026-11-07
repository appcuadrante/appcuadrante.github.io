-- =====================================================================
-- App Cuadrante · INSTALACIÓN COMPLETA DE LA BASE DE DATOS
-- Generado el 06/11/2026 a partir de la base de datos en producción (estado real, no un historial de cambios).
--
-- Para qué sirve: crear desde cero, en un proyecto de Supabase VACÍO, toda la estructura que usa la app (tablas,
-- reglas de seguridad, funciones, automatismos y la configuración de turnos). NO contiene datos de personas.
-- El traspaso normal de la app NO necesita este archivo (el proyecto de Supabase se transfiere entero, con sus datos);
-- sirve como documentación técnica completa y para reinstalar la base de datos si alguna vez hiciera falta.
--
-- Uso: Supabase → SQL Editor → New query → pegar entero → Run (en un proyecto nuevo y vacío).
-- Después: (1) guardar la clave de Brevo en Vault con el nombre brevo_api_key; (2) crear la cuenta del administrador
-- inicial (ver la guía técnica); (3) dar de alta al personal desde la app.
-- =====================================================================

set check_function_bodies = off;  -- las funciones se crean en orden alfabético; se comprueban al usarse

-- =====================================================================
-- 1. EXTENSIONES
-- pg_net: envío de los avisos por correo · supabase_vault: guarda la clave del correo · pgcrypto / uuid-ossp: identificadores.
-- =====================================================================
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_stat_statements with schema extensions;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists supabase_vault;
create extension if not exists "uuid-ossp" with schema extensions;

-- =====================================================================
-- 2. TIPOS
-- Estados de una solicitud de cambio.
-- =====================================================================
create type public.estado_cambio as enum ('pendiente_compañero', 'pendiente_admin', 'aprobado', 'rechazado_compañero', 'rechazado_admin', 'cancelado');

-- =====================================================================
-- 3. SECUENCIAS (numeración automática de los identificadores)
-- =====================================================================
create sequence if not exists public.cuadrante_dia_id_seq;
create sequence if not exists public.departamentos_id_seq;
create sequence if not exists public.historial_claves_id_seq;
create sequence if not exists public.horas_extra_id_seq;
create sequence if not exists public.huecos_id_seq;
create sequence if not exists public.registro_cuadrante_id_seq;
create sequence if not exists public.solicitudes_cambio_id_seq;

-- =====================================================================
-- 4. TABLAS
-- departamentos · codigos_turno · patrones (ciclo de cada turno) · personas · fichas (datos privados) · cuentas (acceso)
-- cuadrante_dia (un registro por persona y día) · solicitudes_cambio · huecos (vacantes/solapes) · horas_extra
-- movilidad_cambios (puesto DGGVC) · habilitaciones (dónde más puede cubrir) · registro_cuadrante (historial)
-- puestos (Vigilantes: V-1…V-4 y motos, con su horario · Agentes: la base) · festivos (de Madrid capital, para las motos)
-- anios_publicados (años siguientes que la plantilla de cada área ya puede ver) · historial_claves (huellas de las 15 últimas
-- contraseñas de cada cuenta; nadie puede leerla desde fuera)
-- =====================================================================
create table public.anios_publicados (
  area text not null,
  anio integer not null,
  publicado_en timestamp with time zone not null default now(),
  publicado_por text
);
create table public.codigos_turno (
  codigo text not null,
  nombre text not null,
  hora_inicio time without time zone,
  hora_fin time without time zone,
  horas numeric not null,
  color text not null
);
create table public.cuadrante_dia (
  id bigint not null default nextval('cuadrante_dia_id_seq'::regclass),
  persona_id uuid not null,
  fecha date not null,
  codigo text not null,
  departamento_id integer,
  nota text,
  puesto text
);
create table public.cuentas (
  id uuid not null default gen_random_uuid(),
  usuario text not null,
  correo text not null,
  nombre text not null,
  rol text not null default 'usuario'::text,
  persona_id uuid,
  activo boolean not null default true,
  created_at timestamp with time zone not null default now(),
  areas text[]
);
create table public.departamentos (
  id integer not null default nextval('departamentos_id_seq'::regclass),
  nombre text not null,
  slug text not null,
  area text not null default 'centro_control'::text,
  grupo text
);
create table public.festivos (
  fecha date not null,
  nombre text not null
);
create table public.fichas (
  persona_id uuid not null,
  nombre text not null default ''::text,
  segundo_nombre text,
  apellido1 text not null default ''::text,
  apellido2 text,
  telefono text,
  numero_empleado text,
  fecha_incorporacion date,
  fecha_baja date,
  contacto_emergencia text,
  telefono_emergencia text,
  observaciones text,
  actualizado_en timestamp with time zone not null default now(),
  formacion_fin_prevista date,
  categoria text,
  nombre_uso text
);
create table public.habilitaciones (
  persona_id uuid not null,
  departamento_id integer not null
);
create table public.historial_claves (
  id bigint generated always as identity not null,
  user_id uuid not null,
  hash text not null,
  cambiada_en timestamp with time zone not null default now()
);
create table public.horas_extra (
  id bigint not null default nextval('horas_extra_id_seq'::regclass),
  persona_id uuid not null,
  fecha date not null,
  tipo text not null,
  horas numeric(4,1) not null,
  nota text,
  hueco_id bigint,
  creado_en timestamp with time zone not null default now(),
  creado_por text
);
create table public.huecos (
  id bigint not null default nextval('huecos_id_seq'::regclass),
  fecha date not null,
  departamento_id integer not null,
  turno_numero integer,
  codigo text not null,
  persona_quitada uuid,
  tipo text not null,
  estado text not null default 'cerrado'::text,
  cubierto_por uuid,
  motivo text,
  creado_en timestamp with time zone not null default now(),
  creado_por text,
  puesto text
);
create table public.movilidad_cambios (
  turno_numero integer not null,
  fecha date not null,
  persona_dggvc uuid not null,
  solicitud_id bigint,
  creado_en timestamp with time zone not null default now()
);
create table public.patrones (
  departamento_id integer not null,
  turno_numero integer not null,
  ciclo integer not null,
  fecha_base date not null,
  secuencia text[] not null,
  actualizado_en timestamp with time zone not null default now()
);
create table public.personas (
  id uuid not null default gen_random_uuid(),
  nombre text not null,
  departamento_id integer not null,
  turno_numero integer,
  operador_indice integer,
  es_plaza_formacion boolean not null default false,
  activo boolean not null default true,
  created_at timestamp with time zone not null default now(),
  nombre_corto text,
  situacion text not null default 'titular'::text,
  puesto text
);
create table public.puestos (
  codigo text not null,
  departamento_id integer not null,
  nombre text not null,
  desfase_horas integer not null default 0,
  orden integer not null default 0,
  se_cubre boolean not null default true
);
create table public.registro_cuadrante (
  id bigint not null default nextval('registro_cuadrante_id_seq'::regclass),
  momento timestamp with time zone not null default now(),
  usuario text,
  persona_id uuid not null,
  fecha date not null,
  codigo_antes text,
  codigo_despues text,
  dep_antes integer,
  dep_despues integer,
  que text not null default 'casilla'::text,
  detalle text,
  motivo text
);
create table public.solicitudes_cambio (
  id bigint not null default nextval('solicitudes_cambio_id_seq'::regclass),
  solicitante_id uuid not null,
  companero_id uuid,
  fecha date not null,
  estado estado_cambio not null default 'pendiente_compañero'::estado_cambio,
  motivo text,
  creado_en timestamp with time zone not null default now(),
  resuelto_en timestamp with time zone,
  resuelto_por uuid,
  tipo text not null default 'cambio'::text,
  fecha_devolucion date,
  codigo_solicitante_1 text,
  codigo_companero_1 text,
  codigo_solicitante_2 text,
  codigo_companero_2 text,
  resuelto_por_usuario text,
  hueco_id bigint,
  movilidad_dggvc uuid,
  dias jsonb
);

alter sequence public.cuadrante_dia_id_seq owned by public.cuadrante_dia.id;
alter sequence public.departamentos_id_seq owned by public.departamentos.id;
alter sequence public.horas_extra_id_seq owned by public.horas_extra.id;
alter sequence public.huecos_id_seq owned by public.huecos.id;
alter sequence public.registro_cuadrante_id_seq owned by public.registro_cuadrante.id;
alter sequence public.solicitudes_cambio_id_seq owned by public.solicitudes_cambio.id;

-- =====================================================================
-- 5. CLAVES PRIMARIAS Y VALORES ÚNICOS
-- =====================================================================
alter table public.anios_publicados add constraint anios_publicados_pkey PRIMARY KEY (area, anio);
alter table public.codigos_turno add constraint codigos_turno_pkey PRIMARY KEY (codigo);
alter table public.cuadrante_dia add constraint cuadrante_dia_persona_id_fecha_key UNIQUE (persona_id, fecha);
alter table public.cuadrante_dia add constraint cuadrante_dia_pkey PRIMARY KEY (id);
alter table public.cuentas add constraint cuentas_correo_key UNIQUE (correo);
alter table public.cuentas add constraint cuentas_pkey PRIMARY KEY (id);
alter table public.cuentas add constraint cuentas_usuario_key UNIQUE (usuario);
alter table public.departamentos add constraint departamentos_pkey PRIMARY KEY (id);
alter table public.departamentos add constraint departamentos_slug_key UNIQUE (slug);
alter table public.festivos add constraint festivos_pkey PRIMARY KEY (fecha);
alter table public.fichas add constraint fichas_pkey PRIMARY KEY (persona_id);
alter table public.habilitaciones add constraint habilitaciones_pkey PRIMARY KEY (persona_id, departamento_id);
alter table public.historial_claves add constraint historial_claves_pkey PRIMARY KEY (id);
alter table public.horas_extra add constraint horas_extra_pkey PRIMARY KEY (id);
alter table public.huecos add constraint huecos_pkey PRIMARY KEY (id);
alter table public.movilidad_cambios add constraint movilidad_cambios_pkey PRIMARY KEY (turno_numero, fecha);
alter table public.patrones add constraint patrones_pkey PRIMARY KEY (departamento_id, turno_numero);
alter table public.personas add constraint personas_pkey PRIMARY KEY (id);
alter table public.puestos add constraint puestos_pkey PRIMARY KEY (codigo);
alter table public.registro_cuadrante add constraint registro_cuadrante_pkey PRIMARY KEY (id);
alter table public.solicitudes_cambio add constraint solicitudes_cambio_pkey PRIMARY KEY (id);

-- =====================================================================
-- 6. RELACIONES ENTRE TABLAS Y COMPROBACIONES
-- =====================================================================
alter table public.anios_publicados add constraint anios_publicados_area_check CHECK ((area = ANY (ARRAY['centro_control'::text, 'incidencias'::text])));
alter table public.cuadrante_dia add constraint cuadrante_dia_codigo_fkey FOREIGN KEY (codigo) REFERENCES codigos_turno(codigo);
alter table public.cuadrante_dia add constraint cuadrante_dia_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES personas(id) ON DELETE CASCADE;
alter table public.cuadrante_dia add constraint cuadrante_dia_puesto_fkey FOREIGN KEY (puesto) REFERENCES puestos(codigo);
alter table public.cuentas add constraint cuentas_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES personas(id) ON DELETE SET NULL;
alter table public.cuentas add constraint cuentas_rol_check CHECK ((rol = ANY (ARRAY['usuario'::text, 'responsable'::text, 'admin'::text])));
alter table public.departamentos add constraint departamentos_area_check CHECK ((area = ANY (ARRAY['centro_control'::text, 'incidencias'::text])));
alter table public.fichas add constraint fichas_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES personas(id) ON DELETE CASCADE;
alter table public.habilitaciones add constraint habilitaciones_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES personas(id) ON DELETE CASCADE;
alter table public.horas_extra add constraint horas_extra_horas_check CHECK (((horas > (0)::numeric) AND (horas <= (24)::numeric)));
alter table public.horas_extra add constraint horas_extra_hueco_id_fkey FOREIGN KEY (hueco_id) REFERENCES huecos(id) ON DELETE SET NULL;
alter table public.horas_extra add constraint horas_extra_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES personas(id) ON DELETE CASCADE;
alter table public.horas_extra add constraint horas_extra_tipo_check CHECK ((tipo = ANY (ARRAY['solape'::text, 'curso'::text, 'extra'::text, 'ajuste'::text, 'fuerza_mayor'::text, 'reten'::text])));
alter table public.huecos add constraint huecos_cubierto_por_fkey FOREIGN KEY (cubierto_por) REFERENCES personas(id) ON DELETE SET NULL;
alter table public.huecos add constraint huecos_estado_check CHECK ((estado = ANY (ARRAY['abierto'::text, 'cubierto'::text, 'cerrado'::text])));
alter table public.huecos add constraint huecos_persona_quitada_fkey FOREIGN KEY (persona_quitada) REFERENCES personas(id) ON DELETE SET NULL;
alter table public.huecos add constraint huecos_puesto_fkey FOREIGN KEY (puesto) REFERENCES puestos(codigo);
alter table public.huecos add constraint huecos_tipo_check CHECK ((tipo = ANY (ARRAY['no_cubrir'::text, 'vacante'::text, 'solape'::text, 'cubierto'::text])));
alter table public.movilidad_cambios add constraint movilidad_cambios_persona_dggvc_fkey FOREIGN KEY (persona_dggvc) REFERENCES personas(id) ON DELETE CASCADE;
alter table public.movilidad_cambios add constraint movilidad_cambios_solicitud_id_fkey FOREIGN KEY (solicitud_id) REFERENCES solicitudes_cambio(id) ON DELETE SET NULL;
alter table public.personas add constraint personas_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES departamentos(id);
alter table public.personas add constraint personas_puesto_fkey FOREIGN KEY (puesto) REFERENCES puestos(codigo);
alter table public.personas add constraint personas_situacion_check CHECK ((situacion = ANY (ARRAY['titular'::text, 'bolsa'::text])));
alter table public.personas add constraint personas_turno_numero_check CHECK (((turno_numero >= 1) AND (turno_numero <= 7)));
alter table public.puestos add constraint puestos_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES departamentos(id);
alter table public.solicitudes_cambio add constraint solicitudes_cambio_companero_id_fkey FOREIGN KEY (companero_id) REFERENCES personas(id);
alter table public.solicitudes_cambio add constraint solicitudes_cambio_hueco_id_fkey FOREIGN KEY (hueco_id) REFERENCES huecos(id) ON DELETE SET NULL;
alter table public.solicitudes_cambio add constraint solicitudes_cambio_movilidad_dggvc_fkey FOREIGN KEY (movilidad_dggvc) REFERENCES personas(id) ON DELETE SET NULL;
alter table public.solicitudes_cambio add constraint solicitudes_cambio_resuelto_por_fkey FOREIGN KEY (resuelto_por) REFERENCES personas(id);
alter table public.solicitudes_cambio add constraint solicitudes_cambio_solicitante_id_fkey FOREIGN KEY (solicitante_id) REFERENCES personas(id);

-- =====================================================================
-- 7. ÍNDICES (búsquedas rápidas)
-- =====================================================================
CREATE INDEX cuadrante_dia_fecha ON public.cuadrante_dia USING btree (fecha);
CREATE INDEX historial_claves_usuario ON public.historial_claves USING btree (user_id, cambiada_en DESC);
CREATE INDEX horas_extra_persona_fecha ON public.horas_extra USING btree (persona_id, fecha);
CREATE INDEX huecos_fecha ON public.huecos USING btree (fecha);
CREATE INDEX idx_cuadrante_persona_fecha ON public.cuadrante_dia USING btree (persona_id, fecha);
CREATE INDEX registro_cuadrante_fecha ON public.registro_cuadrante USING btree (fecha);
CREATE INDEX registro_cuadrante_momento ON public.registro_cuadrante USING btree (momento DESC);

-- =====================================================================
-- 8. FUNCIONES
-- Toda la lógica de negocio está en la base de datos: la app nunca escribe directamente en el cuadrante.
-- Las que empiezan por _ son internas (solo las usan otras funciones); el resto las llama la app con sesión iniciada.
-- =====================================================================

CREATE OR REPLACE FUNCTION public._aal2()
 RETURNS boolean
 LANGUAGE sql
 STABLE
AS $function$
  select coalesce(auth.jwt() ->> 'aal', '') = 'aal2';
$function$
;

CREATE OR REPLACE FUNCTION public._actualizar_nombre_corto()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update personas set nombre_corto = trim(coalesce(nullif(trim(new.nombre_uso), ''), new.nombre) || ' ' || new.apellido1)
  where id = new.persona_id;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public._admin_de_su_area()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.persona_id is not null and new.rol = 'admin' then
    new.areas := array[(select d.area from personas p join departamentos d on d.id = p.departamento_id where p.id = new.persona_id)];
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public._admin_total()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public._aal2() and exists (select 1 from cuentas where correo = lower(auth.jwt() ->> 'email') and rol = 'admin' and activo and areas is null);
$function$
;

CREATE OR REPLACE FUNCTION public._aplicar_horario(s solicitudes_cambio, p_movilidad jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare x jsonb; v_f date[] := '{}'; v_a text[] := '{}'; v_b text[] := '{}'; v_pa text[] := '{}'; v_pb text[] := '{}'; v_msg text;
begin
  for x in select value from jsonb_array_elements(s.dias) loop
    if _codigo(s.solicitante_id, (x->>'f')::date) <> x->>'a' or _codigo(s.companero_id, (x->>'f')::date) <> x->>'b' then
      raise exception 'El cuadrante de esos días ha cambiado desde que se pidió. Hay que rechazarlo y volver a pedirlo.';
    end if;
    if x->>'a' <> x->>'b' then
      v_f := v_f || (x->>'f')::date; v_a := v_a || (x->>'a'); v_b := v_b || (x->>'b');
      v_pa := v_pa || _puesto_dia(s.solicitante_id, (x->>'f')::date); v_pb := v_pb || _puesto_dia(s.companero_id, (x->>'f')::date);
    end if;
  end loop;
  v_msg := coalesce(_fallo_descanso(s.solicitante_id, v_f, v_b, v_pb), _fallo_descanso(s.companero_id, v_f, v_a, v_pa));
  if v_msg is not null then raise exception '%', v_msg; end if;
  perform set_config('app.motivo', 'cambio', true);
  for i in 1 .. coalesce(array_length(v_f, 1), 0) loop
    perform _cambiar_dia(s.solicitante_id, s.companero_id, v_f[i], v_b[i], v_a[i]);
  end loop;
  perform set_config('app.motivo', '', true);
  if p_movilidad is not null then
    for x in select value from jsonb_array_elements(p_movilidad) loop
      if (x->>'persona')::uuid not in (s.solicitante_id, s.companero_id) or (x->>'fecha')::date not between s.fecha and s.fecha_devolucion then continue; end if;
      delete from movilidad_cambios where fecha = (x->>'fecha')::date and persona_dggvc = (x->>'persona')::uuid and turno_numero <> (x->>'turno')::int;
      insert into movilidad_cambios (turno_numero, fecha, persona_dggvc, solicitud_id)
      values ((x->>'turno')::int, (x->>'fecha')::date, (x->>'persona')::uuid, s.id)
      on conflict (turno_numero, fecha) do update set persona_dggvc = excluded.persona_dggvc, solicitud_id = excluded.solicitud_id, creado_en = now();
    end loop;
  end if;
end $function$
;

CREATE OR REPLACE FUNCTION public._avisar_solicitud()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  n   alias for new;
  sol text; com text; m_sol text; m_com text;
  dias text; detalle_com text; detalle_sol text; que text; x jsonb;
  ant text; est text := new.estado::text;
begin
  if tg_op = 'UPDATE' then
    ant := old.estado::text;
    if ant is not distinct from est then return new; end if;
  end if;
  select nombre_corto into sol from personas where id = n.solicitante_id;
  select nombre_corto into com from personas where id = n.companero_id;
  sol := coalesce(sol, 'Un compañero');
  if n.companero_id is not null then com := coalesce(com, 'Tu compañero'); end if;
  m_sol := _correo_persona(n.solicitante_id);
  m_com := _correo_persona(n.companero_id);

  if n.tipo = 'cambio' then
    dias := _fecha_correo(n.fecha) || ' y ' || _fecha_correo(n.fecha_devolucion);
    detalle_com := '· ' || _fecha_correo(n.fecha) || ': harías ' || _codigo_correo(n.codigo_solicitante_1) || ' (ahora tienes ' || _codigo_correo(n.codigo_companero_1) || ')' || E'\n'
                || '· ' || _fecha_correo(n.fecha_devolucion) || ': harías ' || _codigo_correo(n.codigo_solicitante_2) || ' (ahora tienes ' || _codigo_correo(n.codigo_companero_2) || ')';
    detalle_sol := '· ' || _fecha_correo(n.fecha) || ': harás ' || _codigo_correo(n.codigo_companero_1) || E'\n'
                || '· ' || _fecha_correo(n.fecha_devolucion) || ': harás ' || _codigo_correo(n.codigo_companero_2);
    que := 'el cambio de turno de los días ' || dias;
  elsif n.tipo = 'horario' then
    dias := _fecha_correo(n.fecha) || ' al ' || _fecha_correo(n.fecha_devolucion);
    detalle_com := ''; detalle_sol := '';
    for x in select value from jsonb_array_elements(coalesce(n.dias, '[]')) loop
      if x->>'a' <> x->>'b' then
        detalle_com := detalle_com || '· ' || _fecha_correo((x->>'f')::date) || ': harías ' || _codigo_correo(x->>'a') || ' (ahora tienes ' || _codigo_correo(x->>'b') || ')' || E'\n';
        detalle_sol := detalle_sol || '· ' || _fecha_correo((x->>'f')::date) || ': harás ' || _codigo_correo(x->>'b') || E'\n';
      end if;
    end loop;
    que := 'el cambio de horario del ' || dias;
  elsif n.tipo = 'movilidad' then
    dias := _fecha_correo(n.fecha) || case when n.fecha_devolucion is distinct from n.fecha then ' al ' || _fecha_correo(n.fecha_devolucion) else '' end;
    que := 'el cambio de puesto de Movilidad del ' || dias;
  elsif n.tipo = 'dia_libre' then
    que := 'el día libre del ' || _fecha_correo(n.fecha);
  elsif n.tipo = 'vacante' then
    que := 'la vacante del ' || _fecha_correo(n.fecha) || ' (' || _codigo_correo(n.codigo_companero_1) || ')';
  else
    que := 'tu solicitud del ' || _fecha_correo(n.fecha);
  end if;

  if tg_op = 'INSERT' and est = 'pendiente_compañero' then
    if n.tipo in ('cambio', 'horario') then
      perform _enviar_correo(m_com, sol || case when n.tipo = 'horario' then ' te pide un cambio de horario' else ' te pide un cambio de turno' end,
        array[sol || case when n.tipo = 'horario' then ' te pide cambiaros el horario del ' || dias || '. Si aceptas:' else ' te pide un cambio de turno. Si aceptas:' end,
              rtrim(detalle_com, E'\n'), 'Entra en la app → Mis cambios para aceptarlo o rechazarlo.']);
    elsif n.tipo = 'movilidad' then
      perform _enviar_correo(m_com, sol || ' te pide cambiar el puesto de Movilidad',
        array[sol || ' te pide cambiar el puesto de Movilidad el ' || dias || ': '
              || case when n.movilidad_dggvc = n.companero_id then 'tú irías a DGGVC (Movilidad) y ' || sol || ' a CCT.'
                      else sol || ' iría a DGGVC (Movilidad) y tú a CCT.' end || ' El horario no cambia.',
              'Entra en la app → Mis cambios para aceptarlo o rechazarlo.']);
    end if;
    return new;
  end if;
  if tg_op <> 'UPDATE' then return new; end if;

  if ant = 'pendiente_compañero' then
    if est = 'rechazado_compañero' then
      perform _enviar_correo(m_sol, com || ' ha rechazado tu solicitud', array[com || ' ha rechazado ' || que || '.', 'Tu cuadrante no cambia.']);
    elsif est = 'pendiente_admin' then
      perform _enviar_correo(m_sol, com || ' ha aceptado tu cambio: falta el administrador',
        array[com || ' ha aceptado ' || que || '.', 'Como falta poco para esos días, ahora tiene que aprobarlo el administrador. Te avisaremos cuando lo haga.']);
    elsif est = 'aprobado' then
      perform _enviar_correo(m_sol, com || ' ha aceptado: cambio hecho',
        array[com || ' ha aceptado ' || que || '. Ya está en el cuadrante.']
        || case when n.tipo in ('cambio', 'horario') then array[rtrim(detalle_sol, E'\n')] else array[]::text[] end);
    elsif est = 'cancelado' then
      perform _enviar_correo(m_com, sol || ' ha retirado su solicitud', array[sol || ' ha retirado ' || que || '. No tienes que hacer nada.']);
    end if;
    return new;
  end if;

  if ant = 'pendiente_admin' then
    if est = 'aprobado' then
      if n.tipo = 'vacante' then
        perform _enviar_correo(m_sol, 'Te han dado la vacante del ' || _fecha_correo(n.fecha), array['El administrador te ha asignado ' || que || '. Ya está en tu cuadrante.']);
      elsif n.tipo = 'dia_libre' then
        perform _enviar_correo(m_sol, 'Día libre aprobado', array['El administrador ha aprobado ' || que || '. Ya está en tu cuadrante.', 'Recuerda que esas horas quedan pendientes con la empresa.']);
      else
        perform _enviar_correo(m_sol, 'Cambio aprobado',
          array['El administrador ha aprobado ' || que || ' con ' || coalesce(com, 'tu compañero') || '. Ya está en el cuadrante.']
          || case when n.tipo in ('cambio', 'horario') then array[rtrim(detalle_sol, E'\n')] else array[]::text[] end);
        perform _enviar_correo(m_com, 'Cambio aprobado', array['El administrador ha aprobado ' || que || ' con ' || sol || '. Ya está en el cuadrante.']);
      end if;
    elsif est = 'rechazado_admin' then
      if n.tipo = 'vacante' then
        perform _enviar_correo(m_sol, 'Vacante del ' || _fecha_correo(n.fecha) || ': no asignada',
          array['Tu solicitud para ' || que || ' no ha sido aceptada (puede que se haya asignado a otra persona o que ya no haga falta).']);
      else
        perform _enviar_correo(m_sol, 'Solicitud no aprobada',
          array['El administrador no ha aprobado ' || que || case when com is not null then ' con ' || com else '' end || '.', 'Tu cuadrante no cambia.']);
        perform _enviar_correo(m_com, 'Cambio no aprobado', array['El administrador no ha aprobado ' || que || ' con ' || sol || '.', 'Tu cuadrante no cambia.']);
      end if;
    elsif est = 'cancelado' then
      perform _enviar_correo(m_com, sol || ' ha retirado su solicitud', array[sol || ' ha retirado ' || que || '. No tienes que hacer nada.']);
    end if;
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public._cambiar_dia(p_a uuid, p_b uuid, p_fecha date, p_cod_a text, p_cod_b text, p_departamento integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare pa text := _puesto_dia(p_a, p_fecha); pb text := _puesto_dia(p_b, p_fecha);
        da int := _dep_dia(p_a, p_fecha); db int := _dep_dia(p_b, p_fecha);
begin
  if p_departamento is null then
    perform _poner_codigo_en(p_a, p_fecha, p_cod_a, db);
    perform _poner_codigo_en(p_b, p_fecha, p_cod_b, da);
  else
    perform _poner_codigo_en(p_a, p_fecha, p_cod_a, p_departamento);
    perform _poner_codigo_en(p_b, p_fecha, p_cod_b, p_departamento);
  end if;
  perform _dar_puesto(p_a, p_fecha, pb);
  perform _dar_puesto(p_b, p_fecha, pa);
end $function$
;

CREATE OR REPLACE FUNCTION public._clave_caducada(p_user uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce((select max(cambiada_en) from historial_claves where user_id = p_user) < now() - interval '90 days', false);
$function$
;

CREATE OR REPLACE FUNCTION public._clave_en_historial(p_user uuid, p_clave text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  select exists (select 1 from (select hash from historial_claves where user_id = p_user order by cambiada_en desc, id desc limit 15) h
                 where extensions.crypt(p_clave, h.hash) = h.hash);
$function$
;

CREATE OR REPLACE FUNCTION public._codigo(p_persona uuid, p_fecha date)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce((select codigo::text from cuadrante_dia where persona_id = p_persona and fecha = p_fecha limit 1), 'L');
$function$
;

CREATE OR REPLACE FUNCTION public._codigo_correo(p text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case p when 'MT' then 'M/T' when 'TN' then 'T/N' when 'L' then 'libre' when 'C' then 'F' when 'F12' then 'F (12 h)'
                when 'V' then 'vacaciones' else coalesce(p, '—') end;
$function$
;

CREATE OR REPLACE FUNCTION public._copiar_cuadrante(p_persona uuid, p_departamento integer, p_turno integer, p_desde date)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_filas int; v_mas int;
begin
  perform set_config('app.sin_registro', 'on', true);
  delete from cuadrante_dia where persona_id = p_persona and fecha >= p_desde;
  insert into cuadrante_dia (persona_id, fecha, codigo)
  select p_persona, c.fecha, mode() within group (order by c.codigo)
  from cuadrante_dia c join personas p on p.id = c.persona_id
  where p.departamento_id = p_departamento and p.turno_numero = p_turno and p.id <> p_persona and p.activo
    and p.situacion = 'titular' and c.departamento_id is null and c.fecha >= p_desde
  group by c.fecha;
  get diagnostics v_filas = row_count;
  insert into cuadrante_dia (persona_id, fecha, codigo)
  select p_persona, g.fecha::date, codigo_patron(p_departamento, p_turno, g.fecha::date)
  from generate_series(p_desde, make_date(extract(year from current_date)::int + 1, 12, 31), interval '1 day') g(fecha)
  where codigo_patron(p_departamento, p_turno, g.fecha::date) is not null
    and not exists (select 1 from cuadrante_dia c where c.persona_id = p_persona and c.fecha = g.fecha::date);
  get diagnostics v_mas = row_count;
  perform set_config('app.sin_registro', 'off', true);
  return v_filas + v_mas;
end $function$
;

CREATE OR REPLACE FUNCTION public._correo_persona(p uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select c.correo from cuentas c
   where c.persona_id = p and c.activo
     and exists (select 1 from auth.users u where lower(u.email) = c.correo and u.email_confirmed_at is not null)
   limit 1;
$function$
;

CREATE OR REPLACE FUNCTION public._dar_puesto(p_persona uuid, p_fecha date, p_puesto text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update cuadrante_dia c set puesto = case
      when p_puesto is null or c.codigo in ('L', 'V') then null
      when p_puesto = (select _puesto_anio(p.puesto, extract(year from p_fecha)::int) from personas p where p.id = p_persona) then null
      else p_puesto end
   where c.persona_id = p_persona and c.fecha = p_fecha and c.puesto is distinct from p_puesto;
end $function$
;

CREATE OR REPLACE FUNCTION public._dep_dia(p_persona uuid, p_fecha date)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce((select departamento_id from cuadrante_dia where persona_id = p_persona and fecha = p_fecha),
                  (select departamento_id from personas where id = p_persona));
$function$
;

CREATE OR REPLACE FUNCTION public._deps_visibles()
 RETURNS integer[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(array_agg(distinct d.id), '{}') from departamentos d
  where exists (select 1 from cuentas c where c.correo = lower(auth.jwt() ->> 'email') and c.activo and (
          (c.rol = 'admin' and public._aal2() and d.area = any(coalesce(c.areas, array['centro_control', 'incidencias'])))
       or ((c.rol <> 'admin' or not public._aal2()) and (
              d.id = (select p.departamento_id from personas p where p.id = c.persona_id)
           or d.id in (select h.departamento_id from habilitaciones h where h.persona_id = c.persona_id)
           or (d.area = 'centro_control' and exists (select 1 from personas p join departamentos dp on dp.id = p.departamento_id
                                                      where p.id = c.persona_id and dp.area = 'centro_control'))
           or (d.grupo is not null and d.grupo = (select dp.grupo from personas p join departamentos dp on dp.id = p.departamento_id
                                                   where p.id = c.persona_id))))));
$function$
;

CREATE OR REPLACE FUNCTION public._dias_solicitud(s solicitudes_cambio)
 RETURNS TABLE(persona uuid, dia date)
 LANGUAGE sql
 STABLE
AS $function$
  select s.solicitante_id, s.fecha
  union select s.solicitante_id, s.fecha_devolucion where s.fecha_devolucion is not null and s.tipo = 'cambio'
  union select s.companero_id, s.fecha where s.companero_id is not null and s.tipo in ('cambio', 'movilidad', 'horario')
  union select s.companero_id, s.fecha_devolucion where s.companero_id is not null and s.tipo = 'cambio'
  union select x.p, g::date from (values (s.solicitante_id), (s.companero_id)) x(p),
        generate_series(s.fecha, coalesce(s.fecha_devolucion, s.fecha), interval '1 day') g
   where s.tipo in ('movilidad', 'horario') and x.p is not null;
$function$
;

CREATE OR REPLACE FUNCTION public._enviar_correo(p_para text, p_asunto text, p_lineas text[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare v_clave text; v_html text := ''; v_txt text := ''; l text;
begin
  if p_para is null or p_para = '' then return; end if;
  select decrypted_secret into v_clave from vault.decrypted_secrets where name = 'brevo_api_key' limit 1;
  if v_clave is null then raise notice 'Falta la clave de Brevo (brevo_api_key): no se envía el aviso.'; return; end if;
  foreach l in array p_lineas loop
    l := coalesce(l, '');
    v_html := v_html || '<p style="margin:0 0 12px">'
      || replace(replace(replace(replace(l, '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), E'\n', '<br>') || '</p>';
    v_txt := v_txt || l || E'\n\n';
  end loop;
  v_html := '<div style="font-family:Arial,Helvetica,sans-serif;font-size:15px;color:#16324f;max-width:520px">'
    || v_html
    || '<p style="margin:20px 0"><a href="https://appcuadrante.es/" style="background:#16324f;color:#fff;padding:10px 18px;border-radius:8px;text-decoration:none;font-weight:bold">Abrir la app</a></p>'
    || '<p style="font-size:12px;color:#7a8794">Aviso automático de App Cuadrante. No respondas a este correo.</p></div>';
  v_txt := v_txt || 'Abrir la app: https://appcuadrante.es/' || E'\n\n' || 'Aviso automático de App Cuadrante. No respondas a este correo.';
  perform net.http_post(
    url     := 'https://api.brevo.com/v3/smtp/email',
    headers := jsonb_build_object('api-key', v_clave, 'Content-Type', 'application/json', 'accept', 'application/json'),
    body    := jsonb_build_object(
      'sender', jsonb_build_object('name', 'App Cuadrante', 'email', 'no-responder@appcuadrante.es'),
      'to', jsonb_build_array(jsonb_build_object('email', p_para)),
      'subject', p_asunto,
      'htmlContent', v_html,
      'textContent', v_txt));
exception when others then
  raise notice 'No se pudo enviar el aviso a %: %', p_para, sqlerrm;  -- nunca bloquear la solicitud
end $function$
;

CREATE OR REPLACE FUNCTION public._fallo_descanso(p_persona uuid, p_fechas date[], p_codigos text[], p_puestos text[] DEFAULT NULL::text[])
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  d date; c text; idx int; v_ini timestamp; v_fin timestamp; v_pu text; v_des int;
  prev_fin timestamp; prev_fecha date;
  v_hasta date := (select max(x) from unnest(p_fechas) x) + 2;
begin
  d := (select min(x) from unnest(p_fechas) x) - 2;
  while d <= v_hasta loop
    idx := array_position(p_fechas, d);
    c := case when idx is null then _codigo(p_persona, d) else p_codigos[idx] end;
    v_pu := case when idx is not null and p_puestos is not null then p_puestos[idx] else _puesto_dia(p_persona, d) end;
    v_des := coalesce((select desfase_horas from puestos where codigo = v_pu), 0);
    select h.ini + make_interval(hours => v_des), h.fin + make_interval(hours => v_des) into v_ini, v_fin from _horario(c, d) h;
    if v_ini is not null then
      if prev_fin is not null and v_ini - prev_fin < interval '11 hours 59 minutes'
         and (d = any(p_fechas) or prev_fecha = any(p_fechas)) then
        return 'No se cumple el descanso reglamentario.';
      end if;
      prev_fin := v_fin; prev_fecha := d;
    end if;
    d := d + 1;
  end loop;
  return null;
end $function$
;

CREATE OR REPLACE FUNCTION public._fallo_plazo(p_fecha date)
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  select case
    when p_fecha < current_date then 'No se pueden pedir cambios de días que ya han pasado.'
    when p_fecha > (current_date + interval '3 months')::date then 'No se pueden pedir cambios para dentro de más de 3 meses.'
  end;
$function$
;

CREATE OR REPLACE FUNCTION public._fecha_correo(p date)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select (array['dom','lun','mar','mié','jue','vie','sáb'])[extract(dow from p)::int + 1] || ' ' || to_char(p, 'DD/MM/YYYY');
$function$
;

CREATE OR REPLACE FUNCTION public._fecha_tope()
 RETURNS date
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select make_date(greatest(extract(year from current_date)::int,
                            coalesce((select max(anio) from anios_publicados where area = any(public.mis_areas())), 0)), 12, 31);
$function$
;

CREATE OR REPLACE FUNCTION public._generar_anio(p_anio integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_filas int;
begin
  perform set_config('app.sin_registro', 'on', true);
  insert into cuadrante_dia (persona_id, fecha, codigo)
  select p.id, g.fecha::date, codigo_patron(p.departamento_id::int, p.turno_numero::int, g.fecha::date)
  from personas p
  cross join generate_series(make_date(p_anio, 1, 1), make_date(p_anio, 12, 31), interval '1 day') as g(fecha)
  where p.activo and p.situacion = 'titular' and p.turno_numero is not null
    and codigo_patron(p.departamento_id::int, p.turno_numero::int, g.fecha::date) is not null
    and not exists (select 1 from cuadrante_dia c where c.persona_id = p.id and c.fecha = g.fecha::date);
  get diagnostics v_filas = row_count;
  perform set_config('app.sin_registro', 'off', true);
  return v_filas;
end $function$
;

CREATE OR REPLACE FUNCTION public._guardar_clave_historial()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  begin
    if new.encrypted_password is not null and new.encrypted_password <> ''
       and (tg_op = 'INSERT' or new.encrypted_password is distinct from old.encrypted_password) then
      insert into public.historial_claves (user_id, hash) values (new.id, new.encrypted_password);
      delete from public.historial_claves
       where user_id = new.id
         and id not in (select id from public.historial_claves where user_id = new.id order by cambiada_en desc, id desc limit 15);
    end if;
  exception when others then
    raise warning 'historial de contraseñas: %', sqlerrm;   -- nunca bloquear el acceso
  end;
  return null;
end $function$
;

CREATE OR REPLACE FUNCTION public._horario(p_codigo text, p_fecha date, OUT ini timestamp without time zone, OUT fin timestamp without time zone)
 RETURNS record
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select p_fecha + h.i, p_fecha + h.f
  from (values ('M',   interval '7 hours',  interval '15 hours'),
               ('T',   interval '15 hours', interval '23 hours'),
               ('N',   interval '23 hours', interval '31 hours'),
               ('MT',  interval '7 hours',  interval '19 hours'),
               ('TN',  interval '19 hours', interval '31 hours'),
               ('F',   interval '7 hours',  interval '15 hours'),
               ('C',   interval '7 hours',  interval '15 hours'),
               ('F12', interval '7 hours',  interval '19 hours')) as h(c, i, f)
  where h.c = p_codigo;
$function$
;

CREATE OR REPLACE FUNCTION public._horas(p_codigo text)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce((select horas from codigos_turno where codigo = case when p_codigo = 'C' then 'F' else p_codigo end), 0);
$function$
;

CREATE OR REPLACE FUNCTION public._letras(t text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select regexp_replace(translate(lower(coalesce(t, '')), 'áàäâãéèëêíìïîóòöôõúùüûñç', 'aaaaaeeeeiiiiooooouuuunc'), '[^a-z]', '', 'g');
$function$
;

CREATE OR REPLACE FUNCTION public._limpiar_nota_dia()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if new.codigo is distinct from old.codigo and new.codigo not in ('F', 'C', 'F12') then new.nota := null; end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public._mismas_horas()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_dif numeric := 0; x jsonb;
begin
  if new.tipo = 'cambio' then
    -- lo que gana el que lo pide: lo del compañero menos lo suyo, los dos días
    v_dif := _horas(new.codigo_companero_1) - _horas(new.codigo_solicitante_1)
           + _horas(new.codigo_companero_2) - _horas(new.codigo_solicitante_2);
  elsif new.tipo = 'horario' then
    for x in select value from jsonb_array_elements(coalesce(new.dias, '[]')) loop
      v_dif := v_dif + _horas(x->>'b') - _horas(x->>'a');
    end loop;
  else
    return new;
  end if;
  if v_dif <> 0 then
    raise exception 'No son las mismas horas: uno de los dos quedaría debiendo % h al otro. Elige un día (o unos días) con las mismas horas.', abs(v_dif);
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public._personas_visibles()
 RETURNS uuid[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(array_agg(p.id), '{}') from personas p where p.departamento_id = any(public._deps_visibles());
$function$
;

CREATE OR REPLACE FUNCTION public._poner_codigo(p_persona uuid, p_fecha date, p_codigo text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update cuadrante_dia set codigo = p_codigo, departamento_id = null,
         puesto = case when codigo is distinct from p_codigo then null else puesto end
   where persona_id = p_persona and fecha = p_fecha;
  if not found then insert into cuadrante_dia (persona_id, fecha, codigo) values (p_persona, p_fecha, p_codigo); end if;
end $function$
;

CREATE OR REPLACE FUNCTION public._poner_codigo_en(p_persona uuid, p_fecha date, p_codigo text, p_departamento integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_dep int := case when p_departamento = (select departamento_id from personas where id = p_persona) then null else p_departamento end;
begin
  update cuadrante_dia set codigo = p_codigo, departamento_id = case when p_codigo = 'L' then null else v_dep end,
         puesto = case when codigo is distinct from p_codigo then null else puesto end
   where persona_id = p_persona and fecha = p_fecha;
  if not found then
    insert into cuadrante_dia (persona_id, fecha, codigo, departamento_id) values (p_persona, p_fecha, p_codigo, case when p_codigo = 'L' then null else v_dep end);
  end if;
end $function$
;

CREATE OR REPLACE FUNCTION public._pueden_cambiarse(p_a uuid, p_b uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from personas a, personas b
    where a.id = p_a and b.id = p_b and a.id <> b.id and a.activo and b.activo
      and (a.departamento_id = b.departamento_id
           or (exists (select 1 from habilitaciones h where h.persona_id = a.id and h.departamento_id = b.departamento_id)
               and exists (select 1 from habilitaciones h where h.persona_id = b.id and h.departamento_id = a.departamento_id))));
$function$
;

CREATE OR REPLACE FUNCTION public._puesto_anio(p_puesto text, p_anio integer)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case when abs(p_anio - 2026) % 2 = 1 then
           case p_puesto when 'V-1' then 'V-3' when 'V-3' then 'V-1' when 'V-2' then 'V-4' when 'V-4' then 'V-2' else p_puesto end
         else p_puesto end;
$function$
;

CREATE OR REPLACE FUNCTION public._puesto_dia(p_persona uuid, p_fecha date)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce((select puesto from cuadrante_dia where persona_id = p_persona and fecha = p_fecha),
                  (select _puesto_anio(puesto, extract(year from p_fecha)::int) from personas where id = p_persona));
$function$
;

CREATE OR REPLACE FUNCTION public._puesto_movilidad(p_persona uuid, p_fecha date)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    (select turno_numero from movilidad_cambios where fecha = p_fecha and persona_dggvc = p_persona limit 1),
    (select turno_numero from personas where id = p_persona)
  );
$function$
;

CREATE OR REPLACE FUNCTION public._registrar_cuadrante()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if coalesce(current_setting('app.sin_registro', true), '') = 'on' then return null; end if;
  if tg_op = 'UPDATE' and old.codigo is not distinct from new.codigo
     and old.departamento_id is not distinct from new.departamento_id then return null; end if;
  insert into registro_cuadrante (usuario, persona_id, fecha, codigo_antes, codigo_despues, dep_antes, dep_despues, motivo)
  values ((select usuario from cuentas where correo = lower(auth.jwt() ->> 'email') limit 1),
          case when tg_op = 'DELETE' then old.persona_id else new.persona_id end,
          case when tg_op = 'DELETE' then old.fecha else new.fecha end,
          case when tg_op = 'INSERT' then null else old.codigo::text end,
          case when tg_op = 'DELETE' then null else new.codigo::text end,
          case when tg_op = 'INSERT' then null else old.departamento_id end,
          case when tg_op = 'DELETE' then null else new.departamento_id end,
          nullif(current_setting('app.motivo', true), ''));
  return null;
end $function$
;

CREATE OR REPLACE FUNCTION public._registrar_horas()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare x horas_extra;
begin
  if tg_op = 'DELETE' then x := old; else x := new; end if;
  if tg_op = 'UPDATE' and old.horas is not distinct from new.horas and old.tipo is not distinct from new.tipo
     and old.nota is not distinct from new.nota and old.fecha is not distinct from new.fecha then return null; end if;
  insert into registro_cuadrante (usuario, persona_id, fecha, que, detalle)
  values ((select usuario from cuentas where correo = lower(auth.jwt() ->> 'email') limit 1),
          x.persona_id, x.fecha,
          case when tg_op = 'DELETE' then 'horas_quitadas' else 'horas_anadidas' end,
          '+' || rtrim(rtrim(to_char(x.horas, 'FM990.0'), '0'), '.') || ' h ' || x.tipo || coalesce(' · ' || nullif(x.nota, ''), ''));
  return null;
end $function$
;

CREATE OR REPLACE FUNCTION public._renumerar_operadores(p_departamento integer, p_turno integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if (select slug from departamentos where id = p_departamento) <> 'cct' or p_turno is null then return; end if;
  update personas set operador_indice = null
   where departamento_id = p_departamento and turno_numero = p_turno and (not activo or situacion <> 'titular');
  update personas p set operador_indice = r.n
  from (select id, row_number() over (order by operador_indice nulls last, created_at) as n
        from personas where departamento_id = p_departamento and turno_numero = p_turno and activo and situacion = 'titular') r
  where p.id = r.id;
end $function$
;

CREATE OR REPLACE FUNCTION public._sin_vacaciones()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_hasta date := case when new.tipo = 'horario' then coalesce(new.fecha_devolucion, new.fecha) else new.fecha end;
begin
  if exists (
    select 1 from cuadrante_dia c
    where c.persona_id in (new.solicitante_id, new.companero_id) and c.codigo = 'V'
      and ((c.fecha between new.fecha and v_hasta) or c.fecha = new.fecha_devolucion)
  ) then
    raise exception 'Ese día hay vacaciones (V): no se pueden pedir cambios.';
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public._solo_anios_publicados()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if public.es_admin() then return new; end if;
  if greatest(new.fecha, coalesce(new.fecha_devolucion, new.fecha)) > public._fecha_tope() then
    raise exception 'El cuadrante de ese año todavía no está publicado. Si necesitas un cambio para esas fechas, pídeselo a tu administrador.';
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public._solo_cuentas_dadas_de_alta()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from public.cuentas where correo = lower(new.email) and activo) then
    raise exception 'Este correo no está dado de alta en App Cuadrante.';
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public._solo_mi_area()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_col text := tg_argv[0];          -- columna con la persona ('-' si la fila no tiene persona; 'cct' = Movilidad)
  v_fila jsonb;
  v_deps int[];
  v_dep int;
  v_ret record;
begin
  if tg_op = 'DELETE' then v_ret := old; else v_ret := new; end if;
  -- Procesos automáticos (generar año, copiar cuadrante de un turno, caducar solicitudes)
  if current_setting('app.sin_registro', true) = 'on' or current_setting('app.sin_aviso', true) = 'on' then return v_ret; end if;
  -- Solo se vigila a los administradores con áreas limitadas
  if not exists (select 1 from cuentas where correo = lower(auth.jwt() ->> 'email') and rol = 'admin' and activo and areas is not null) then
    return v_ret;
  end if;

  if v_col = 'cct' then
    if not ('centro_control' = any(mis_areas())) then raise exception 'Eso no es de tu área: no puedes cambiarlo.'; end if;
    return v_ret;
  end if;

  -- Dar el rol de administrador (o cambiar sus áreas) solo lo hace el administrador de todas las áreas
  if tg_table_name = 'cuentas' then
    if tg_op = 'INSERT' then
      if new.rol = 'admin' then raise exception 'Solo el administrador general puede dar permisos de administrador.'; end if;
    elsif tg_op = 'UPDATE' then
      if new.rol = 'admin' and (old.rol is distinct from 'admin' or old.areas is distinct from new.areas) then
        raise exception 'Solo el administrador general puede dar permisos de administrador.';
      end if;
    end if;
  end if;

  v_deps := _deps_visibles();
  for v_fila in select x from unnest(case tg_op when 'INSERT' then array[to_jsonb(new)]
                                                when 'DELETE' then array[to_jsonb(old)]
                                                else array[to_jsonb(old), to_jsonb(new)] end) x loop
    if (v_fila ->> 'departamento_id') is not null and not ((v_fila ->> 'departamento_id')::int = any(v_deps)) then
      raise exception 'Eso no es de tu área: no puedes cambiarlo.';
    end if;
    if v_col <> '-' and (v_fila ->> v_col) is not null then
      select departamento_id into v_dep from personas where id = (v_fila ->> v_col)::uuid;
      if v_dep is not null and not (v_dep = any(v_deps)) then
        raise exception 'Esa persona no es de tu área: no puedes cambiarla.';
      end if;
    end if;
  end loop;
  return v_ret;
end $function$
;

CREATE OR REPLACE FUNCTION public._un_dia_una_solicitud()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_dia date; v_quien uuid;
begin
  if new.estado not in ('pendiente_compañero', 'pendiente_admin') then return new; end if;
  select n.dia, n.persona into v_dia, v_quien
    from _dias_solicitud(new) n
    join solicitudes_cambio s on s.estado in ('pendiente_compañero', 'pendiente_admin') and s.id is distinct from new.id
    join lateral _dias_solicitud(s) o on o.persona = n.persona and o.dia = n.dia
   where not (new.tipo = 'vacante' and s.tipo = 'vacante' and s.hueco_id = new.hueco_id and s.solicitante_id <> new.solicitante_id)
   limit 1;
  if v_dia is not null then
    if v_quien = new.solicitante_id then
      raise exception 'Ya tienes una solicitud pendiente para el %. Retírala en «Mis cambios» o espera a que se resuelva.', to_char(v_dia, 'DD/MM/YYYY');
    else
      raise exception 'Tu compañero ya tiene una solicitud pendiente para el %. Espera a que se resuelva.', to_char(v_dia, 'DD/MM/YYYY');
    end if;
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.activar_admin(p_usuario text, p_activo boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare c cuentas;
begin
  if not _admin_total() then raise exception 'Solo el administrador general puede hacer esto.'; end if;
  select * into c from cuentas where usuario = lower(trim(p_usuario)) and rol = 'admin' and persona_id is null;
  if not found then raise exception 'Ese administrador no existe.'; end if;
  if c.correo = lower(auth.jwt() ->> 'email') then raise exception 'No puedes quitarte el acceso a ti mismo.'; end if;
  update cuentas set activo = p_activo where id = c.id;
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_intercambiar(p_a uuid, p_b uuid, p_desde date, p_hasta date, p_departamento integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare d date := p_desde; n int := 0; ca text; cb text; na text; nb text;
begin
  if not es_admin() then raise exception 'Solo el administrador puede editar el cuadrante.'; end if;
  if p_a is null or p_b is null or p_a = p_b then raise exception 'Elige dos personas distintas.'; end if;
  if p_hasta < p_desde then raise exception 'La fecha final no puede ser anterior a la inicial.'; end if;
  if p_hasta - p_desde > 62 then raise exception 'Como mucho 2 meses de una vez.'; end if;
  perform set_config('app.motivo', 'cambio', true);
  while d <= p_hasta loop
    ca := _codigo(p_a, d); cb := _codigo(p_b, d);
    if ca is distinct from cb then
      select nota into na from cuadrante_dia where persona_id = p_a and fecha = d;
      select nota into nb from cuadrante_dia where persona_id = p_b and fecha = d;
      perform _cambiar_dia(p_a, p_b, d, cb, ca, p_departamento);
      update cuadrante_dia set nota = nb where persona_id = p_a and fecha = d and codigo in ('F', 'C', 'F12');
      update cuadrante_dia set nota = na where persona_id = p_b and fecha = d and codigo in ('F', 'C', 'F12');
      n := n + 1;
    end if;
    d := d + 1;
  end loop;
  perform set_config('app.motivo', '', true);
  return n;
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_nota_dia(p_persona uuid, p_desde date, p_hasta date, p_nota text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n int;
begin
  if not es_admin() then raise exception 'Solo el administrador puede hacer esto.'; end if;
  if p_hasta < p_desde then raise exception 'Fechas no válidas.'; end if;
  update cuadrante_dia set nota = nullif(trim(p_nota), '')
   where persona_id = p_persona and fecha between p_desde and p_hasta and codigo in ('F', 'C', 'F12');
  get diagnostics n = row_count;
  return n;
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_poner_codigo(p_persona uuid, p_fecha date, p_codigo text, p_departamento integer DEFAULT NULL::integer, p_motivo text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not es_admin() then raise exception 'Solo el administrador puede editar el cuadrante.'; end if;
  if not exists (select 1 from codigos_turno where codigo = p_codigo) then raise exception 'El código % no existe.', p_codigo; end if;
  if p_motivo is not null and p_motivo not in ('extra', 'ajuste', 'fuerza_mayor', 'reten') then raise exception 'Motivo no válido.'; end if;
  perform set_config('app.motivo', coalesce(p_motivo, ''), true);
  if p_departamento is null then perform _poner_codigo(p_persona, p_fecha, p_codigo);
  else perform _poner_codigo_en(p_persona, p_fecha, p_codigo, p_departamento); end if;
  perform set_config('app.motivo', '', true);
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_poner_codigo_rango(p_persona uuid, p_desde date, p_hasta date, p_codigo text, p_departamento integer DEFAULT NULL::integer, p_motivo text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare d date := p_desde; n int := 0;
begin
  if not es_admin() then raise exception 'Solo el administrador puede editar el cuadrante.'; end if;
  if not exists (select 1 from codigos_turno where codigo = p_codigo) then raise exception 'El código % no existe.', p_codigo; end if;
  if p_hasta < p_desde then raise exception 'La fecha final no puede ser anterior a la inicial.'; end if;
  if p_hasta - p_desde > 62 then raise exception 'Como mucho 2 meses de una vez.'; end if;
  if p_motivo is not null and p_motivo not in ('extra', 'ajuste', 'fuerza_mayor', 'reten') then raise exception 'Motivo no válido.'; end if;
  perform set_config('app.motivo', coalesce(p_motivo, ''), true);
  while d <= p_hasta loop
    if p_departamento is null then perform _poner_codigo(p_persona, d, p_codigo);
    else perform _poner_codigo_en(p_persona, d, p_codigo, p_departamento); end if;
    n := n + 1; d := d + 1;
  end loop;
  perform set_config('app.motivo', '', true);
  return n;
end $function$
;

CREATE OR REPLACE FUNCTION public.anadir_horas(p_persona uuid, p_fecha date, p_tipo text, p_horas numeric, p_nota text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id bigint; v_admin text;
begin
  if not es_admin() then raise exception 'Solo el administrador puede añadir horas.'; end if;
  if p_tipo not in ('solape', 'curso', 'extra', 'ajuste', 'fuerza_mayor', 'reten') then raise exception 'Tipo no válido.'; end if;
  if p_horas is null or p_horas <= 0 or p_horas > 24 then raise exception 'Las horas tienen que estar entre 0,5 y 24.'; end if;
  select usuario into v_admin from cuentas where correo = lower(auth.jwt() ->> 'email');
  insert into horas_extra (persona_id, fecha, tipo, horas, nota, creado_por)
  values (p_persona, p_fecha, p_tipo, p_horas, nullif(trim(p_nota), ''), v_admin) returning id into v_id;
  return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.anio_visible()
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select extract(year from public._fecha_tope())::int;
$function$
;

CREATE OR REPLACE FUNCTION public.areas_admin(p_usuario text, p_areas text[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare c cuentas; v text[] := p_areas;
begin
  if not _admin_total() then raise exception 'Solo el administrador general puede hacer esto.'; end if;
  select * into c from cuentas where usuario = lower(trim(p_usuario)) and rol = 'admin' and persona_id is null;
  if not found then raise exception 'Ese administrador no existe.'; end if;
  if c.usuario = 'admin' then raise exception 'La cuenta admin general ve siempre todas las áreas.'; end if;
  if v is not null and not (v <@ array['centro_control', 'incidencias']) then raise exception 'Área no válida.'; end if;
  if v is not null and cardinality(v) = 0 then raise exception 'Elige al menos un área.'; end if;
  if v is not null and cardinality(v) = 2 then v := null; end if;
  update cuentas set areas = v where id = c.id;
end $function$
;

CREATE OR REPLACE FUNCTION public.asegurar_anio_siguiente()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_sig int := extract(year from current_date)::int + 1; v_esperadas bigint; v_hay bigint;
begin
  if current_date < make_date(v_sig - 1, 12, 20) then return 0; end if;
  select count(*) * (make_date(v_sig, 12, 31) - make_date(v_sig, 1, 1) + 1) into v_esperadas
    from personas where activo and situacion = 'titular' and turno_numero is not null;
  select count(*) into v_hay
    from cuadrante_dia c join personas p on p.id = c.persona_id
   where p.activo and p.situacion = 'titular' and p.turno_numero is not null
     and c.fecha between make_date(v_sig, 1, 1) and make_date(v_sig, 12, 31);
  if v_hay >= v_esperadas then return 0; end if;
  return _generar_anio(v_sig);
end $function$
;

CREATE OR REPLACE FUNCTION public.asignar_hueco(p_hueco bigint, p_persona uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare h huecos; v_admin text;
begin
  if not es_admin() then raise exception 'Solo el administrador puede asignar vacantes.'; end if;
  select * into h from huecos where id = p_hueco for update;
  if not found or h.estado <> 'abierto' then raise exception 'Esa vacante ya no está abierta.'; end if;
  if not exists (select 1 from personas where id = p_persona and activo) then raise exception 'Esa persona no está activa.'; end if;
  select usuario into v_admin from cuentas where correo = lower(auth.jwt() ->> 'email');
  perform _poner_codigo_en(p_persona, h.fecha, h.codigo, h.departamento_id);
  perform _dar_puesto(p_persona, h.fecha, h.puesto);
  update huecos set estado = 'cubierto', cubierto_por = p_persona where id = h.id;
  update solicitudes_cambio set estado = case when solicitante_id = p_persona then 'aprobado' else 'rechazado_admin' end::estado_cambio,
         resuelto_en = now(), resuelto_por_usuario = v_admin
   where hueco_id = h.id and estado = 'pendiente_admin';
end $function$
;

CREATE OR REPLACE FUNCTION public.borrar_admin(p_usuario text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare c cuentas;
begin
  if not _admin_total() then raise exception 'Solo el administrador general puede hacer esto.'; end if;
  select * into c from cuentas where usuario = lower(trim(p_usuario)) and rol = 'admin' and persona_id is null;
  if not found then raise exception 'Ese administrador no existe.'; end if;
  if c.usuario = 'admin' then raise exception 'La cuenta admin general no se puede eliminar.'; end if;
  if c.correo = lower(auth.jwt() ->> 'email') then raise exception 'No puedes eliminarte a ti mismo.'; end if;
  delete from auth.users where lower(email) = c.correo;
  delete from cuentas where id = c.id;
end $function$
;

CREATE OR REPLACE FUNCTION public.borrar_horas(p_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not es_admin() then raise exception 'Solo el administrador puede quitar horas.'; end if;
  delete from horas_extra where id = p_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.caducar_solicitudes()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n int;
begin
  perform set_config('app.sin_aviso', 'on', true);
  update solicitudes_cambio
     set estado = 'cancelado', resuelto_en = now(), resuelto_por_usuario = 'caducada'
   where estado in ('pendiente_compañero', 'pendiente_admin')
     and least(fecha, coalesce(fecha_devolucion, fecha)) < (now() at time zone 'Europe/Madrid')::date;
  get diagnostics n = row_count;
  perform set_config('app.sin_aviso', '', true);
  return n;
end $function$
;

CREATE OR REPLACE FUNCTION public.cancelar_solicitud(p_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare s solicitudes_cambio;
begin
  select * into s from solicitudes_cambio where id = p_id for update;
  if not found or s.solicitante_id is distinct from mi_persona() then raise exception 'Solo puedes retirar tus propias solicitudes.'; end if;
  if s.estado not in ('pendiente_compañero', 'pendiente_admin') then raise exception 'Esta solicitud ya está resuelta.'; end if;
  update solicitudes_cambio set estado = 'cancelado', resuelto_en = now() where id = p_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.cerrar_hueco(p_hueco bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_admin text;
begin
  if not es_admin() then raise exception 'Solo el administrador puede cerrar vacantes.'; end if;
  select usuario into v_admin from cuentas where correo = lower(auth.jwt() ->> 'email');
  update huecos set estado = 'cerrado' where id = p_hueco and estado = 'abierto';
  update solicitudes_cambio set estado = 'rechazado_admin', resuelto_en = now(), resuelto_por_usuario = v_admin
   where hueco_id = p_hueco and estado = 'pendiente_admin';
end $function$
;

CREATE OR REPLACE FUNCTION public.clave_caducada()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select auth.uid() is not null and public._clave_caducada(auth.uid());
$function$
;

CREATE OR REPLACE FUNCTION public.clave_usada_antes(p_clave text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select auth.uid() is not null and public._clave_en_historial(auth.uid(), p_clave);
$function$
;

CREATE OR REPLACE FUNCTION public.codigo_patron(p_departamento integer, p_turno integer, p_fecha date)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case
           when p_turno in (6, 7) and exists (select 1 from departamentos d where d.id = p_departamento and d.slug = 'vig')
                and exists (select 1 from festivos f where f.fecha = p_fecha) then 'L'
           else pt.secuencia[(((p_fecha - pt.fecha_base) % pt.ciclo) + pt.ciclo) % pt.ciclo + 1]
         end
  from patrones pt where pt.departamento_id = p_departamento and pt.turno_numero = p_turno;
$function$
;

CREATE OR REPLACE FUNCTION public.companeros_otro_rango()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select b.id from personas b
  where b.activo and b.departamento_id <> (select departamento_id from personas where id = public.mi_persona())
    and public._pueden_cambiarse(public.mi_persona(), b.id);
$function$
;

CREATE OR REPLACE FUNCTION public.correo_de_usuario(p_usuario text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select correo from cuentas where usuario = lower(trim(p_usuario)) and activo limit 1;
$function$
;

CREATE OR REPLACE FUNCTION public.cubrir_con_solape(p_hueco bigint, p_m uuid, p_n uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare h huecos; v_admin text;
begin
  if not es_admin() then raise exception 'Solo el administrador puede hacer esto.'; end if;
  select * into h from huecos where id = p_hueco for update;
  if not found or h.tipo <> 'vacante' or h.estado <> 'abierto' then raise exception 'Esa vacante ya no está abierta.'; end if;
  if h.codigo <> 'T' then raise exception 'El solape solo es para el turno de tarde.'; end if;
  if p_m is null and p_n is null then raise exception 'Elige al menos a una persona.'; end if;
  select usuario into v_admin from cuentas where correo = lower(auth.jwt() ->> 'email');
  if p_m is not null then
    insert into horas_extra (persona_id, fecha, tipo, horas, nota, hueco_id, creado_por)
    values (p_m, h.fecha, 'solape', 4, 'Amplía la mañana (solape de tarde)', h.id, v_admin);
  end if;
  if p_n is not null then
    insert into horas_extra (persona_id, fecha, tipo, horas, nota, hueco_id, creado_por)
    values (p_n, h.fecha, 'solape', 4, 'Entra 4 h antes de noche (solape de tarde)', h.id, v_admin);
  end if;
  update huecos set tipo = 'solape', estado = 'cerrado' where id = h.id;
  update solicitudes_cambio set estado = 'rechazado_admin', resuelto_en = now(), resuelto_por_usuario = v_admin
   where hueco_id = h.id and estado = 'pendiente_admin';
end $function$
;

CREATE OR REPLACE FUNCTION public.dar_baja_persona(p_persona uuid, p_fecha date DEFAULT CURRENT_DATE)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v personas;
begin
  if not es_admin() then raise exception 'Solo el administrador puede dar de baja.'; end if;
  select * into v from personas where id = p_persona for update;
  if not found then raise exception 'Esa persona no existe.'; end if;
  update personas set activo = false where id = p_persona;
  update fichas set fecha_baja = coalesce(p_fecha, current_date), actualizado_en = now() where persona_id = p_persona;
  update cuentas set activo = false where persona_id = p_persona;
  perform _renumerar_operadores(v.departamento_id::int, v.turno_numero::int);
end $function$
;

CREATE OR REPLACE FUNCTION public.es_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public._aal2() and exists (select 1 from cuentas where correo = lower(auth.jwt() ->> 'email') and rol = 'admin' and activo);
$function$
;

CREATE OR REPLACE FUNCTION public.extras_del_anio(p_anio integer)
 RETURNS TABLE(persona_id uuid, fecha date, codigo text, horas numeric, tipo text, origen text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with vis as (select case when public.es_admin() then public._personas_visibles() else array[public.mi_persona()] end as ids,
                      public.es_admin() or p_anio <= extract(year from public._fecha_tope()) as ve),
  r as (
    select x.id, x.persona_id, x.fecha, x.momento, x.codigo_antes, x.codigo_despues, x.motivo
    from registro_cuadrante x, vis
    where vis.ve and coalesce(x.que, 'casilla') = 'casilla'
      and x.fecha between make_date(p_anio, 1, 1) and make_date(p_anio, 12, 31)
      and x.persona_id = any(vis.ids)
  ),
  orig as (
    select distinct on (persona_id, fecha) persona_id, fecha, coalesce(codigo_antes, 'L') as codigo
    from r order by persona_id, fecha, momento, id
  ),
  entrada as (
    select distinct on (persona_id, fecha) persona_id, fecha, motivo
    from r where coalesce(codigo_antes, 'L') in ('L', 'V') and coalesce(codigo_despues, 'L') not in ('L', 'V')
    order by persona_id, fecha, momento desc, id desc
  )
  select c.persona_id, c.fecha, c.codigo, _horas(c.codigo), coalesce(nullif(e.motivo, ''), 'extra'), 'dia'
  from cuadrante_dia c
  join orig o on o.persona_id = c.persona_id and o.fecha = c.fecha
  join entrada e on e.persona_id = c.persona_id and e.fecha = c.fecha
  where c.codigo not in ('L', 'V') and o.codigo = 'L' and coalesce(e.motivo, '') <> 'cambio'
  union all
  select h.persona_id, h.fecha, null, h.horas, h.tipo, 'horas'
  from horas_extra h, vis
  where vis.ve and h.fecha between make_date(p_anio, 1, 1) and make_date(p_anio, 12, 31)
    and h.tipo in ('extra', 'curso', 'fuerza_mayor', 'reten', 'ajuste')
    and h.persona_id = any(vis.ids)
  order by 1, 2;
$function$
;

CREATE OR REPLACE FUNCTION public.fijar_fin_formacion(p_persona uuid, p_fecha date)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not es_admin() then raise exception 'Solo el administrador.'; end if;
  update fichas set formacion_fin_prevista = p_fecha, actualizado_en = now() where persona_id = p_persona;
end $function$
;

CREATE OR REPLACE FUNCTION public.generar_anio(p_anio integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not es_admin() then raise exception 'Solo el administrador puede generar un año.'; end if;
  return _generar_anio(p_anio);
end $function$
;

CREATE OR REPLACE FUNCTION public.guardar_admin(p jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v_nombre text := trim(coalesce(p->>'nombre', ''));
  v_ap1 text := trim(coalesce(p->>'apellido1', ''));
  v_ap2 text := nullif(trim(coalesce(p->>'apellido2', '')), '');
  v_correo text := lower(trim(coalesce(p->>'correo', '')));
  v_areas text[] := (select array_agg(x) from jsonb_array_elements_text(coalesce(p->'areas', '[]'::jsonb)) x);
  v_usuario text;
begin
  if not _admin_total() then raise exception 'Solo el administrador general puede dar de alta administradores.'; end if;
  if v_nombre = '' or v_ap1 = '' then raise exception 'El nombre y el primer apellido son obligatorios.'; end if;
  if v_correo !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'El correo de empresa no es válido.'; end if;
  if exists (select 1 from cuentas where correo = v_correo) then raise exception 'Ya hay una cuenta con el correo %.', v_correo; end if;
  if v_areas is not null and not (v_areas <@ array['centro_control', 'incidencias']) then raise exception 'Área no válida.'; end if;
  if v_areas is not null and cardinality(v_areas) = 2 then v_areas := null; end if;   -- las tres = todas
  v_usuario := lower(trim(coalesce(nullif(p->>'usuario', ''), sugerir_usuario(v_nombre, v_ap1, v_ap2, null))));
  if v_usuario is null or v_usuario !~ '^[a-z0-9]{3,}$' then raise exception 'El usuario solo puede tener letras y números (mínimo 3).'; end if;
  if exists (select 1 from cuentas where usuario = v_usuario) then raise exception 'El usuario % ya existe.', v_usuario; end if;
  insert into cuentas (usuario, correo, nombre, rol, persona_id, activo, areas)
  values (v_usuario, v_correo, regexp_replace(trim(concat_ws(' ', v_nombre, v_ap1, v_ap2)), '\s+', ' ', 'g'), 'admin', null, true, v_areas);
  return v_usuario;
end $function$
;

CREATE OR REPLACE FUNCTION public.guardar_ficha_extra(p_persona uuid, p_categoria text, p_nombre_uso text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not es_admin() then raise exception 'Solo el administrador puede gestionar personas.'; end if;
  update fichas set categoria = nullif(upper(trim(p_categoria)), ''), nombre_uso = nullif(trim(p_nombre_uso), ''), actualizado_en = now()
  where persona_id = p_persona;
end $function$
;

CREATE OR REPLACE FUNCTION public.guardar_persona(p jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v_id uuid := nullif(p->>'persona_id', '')::uuid;
  v_dep int := (p->>'departamento_id')::int;
  -- formación = bolsa
  v_sit text := case when p->>'situacion' in ('bolsa', 'formacion') or coalesce((p->>'es_plaza_formacion')::boolean, false) then 'bolsa'
                     else coalesce(nullif(p->>'situacion', ''), 'titular') end;
  v_turno int := case when v_sit = 'bolsa' then null else nullif(p->>'turno_numero', '')::int end;
  v_nombre text := trim(coalesce(p->>'nombre', ''));
  v_ap1 text := trim(coalesce(p->>'apellido1', ''));
  v_completo text;
  v_correo text := lower(trim(coalesce(p->>'correo', '')));
  v_usuario text;
  v_rol text := coalesce(nullif(p->>'rol', ''), 'usuario');
  v_desde date := coalesce(nullif(p->>'fecha_incorporacion', '')::date, current_date);
  v_cambio date := coalesce(nullif(p->>'cambio_desde', '')::date, current_date);
  v_hab int[] := coalesce((select array_agg(x::int) from jsonb_array_elements_text(coalesce(p->'habilitaciones', '[]'::jsonb)) x), '{}');
  v_ant personas;
  v_correo_ant text;
  v_es_vig boolean;
  v_es_aiam boolean;
  v_puesto text;
begin
  if not es_admin() then raise exception 'Solo el administrador puede gestionar personas.'; end if;
  if v_sit not in ('titular', 'bolsa') then raise exception 'Situación no válida.'; end if;
  if v_nombre = '' or v_ap1 = '' then raise exception 'El nombre y el primer apellido son obligatorios.'; end if;
  if v_dep is null or not exists (select 1 from departamentos where id = v_dep) then raise exception 'Elige el departamento.'; end if;
  v_es_vig := (select slug from departamentos where id = v_dep) = 'vig';
  v_es_aiam := (select grupo from departamentos where id = v_dep) is not distinct from 'aiam';
  if v_sit <> 'bolsa' and (v_turno is null or v_turno not between 1 and (case when v_es_vig then 7 else 5 end)) then raise exception 'Elige el turno.'; end if;
  if v_correo !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'El correo de empresa no es válido.'; end if;
  if v_rol not in ('usuario', 'responsable', 'admin') then raise exception 'Rol no válido.'; end if;
  -- Puesto: Vigilantes (motos según su turno; equipos V-1…V-4) y AIAM (la base); en los demás no hay
  if v_es_aiam then
    v_puesto := case when p ? 'puesto' then nullif(p->>'puesto', '') else (select puesto from personas where id = v_id) end;
    if v_puesto is not null and not exists (select 1 from puestos where codigo = v_puesto and departamento_id = v_dep) then v_puesto := null; end if;
    if v_sit = 'titular' and v_puesto is null then raise exception 'Elige la base.'; end if;
  elsif not v_es_vig then v_puesto := null;
  elsif v_turno = 6 then v_puesto := 'M-1';
  elsif v_turno = 7 then v_puesto := 'M-3';
  elsif p ? 'puesto' then v_puesto := nullif(p->>'puesto', '');
  else v_puesto := (select puesto from personas where id = v_id);
  end if;
  if v_es_vig and v_puesto is not null and v_turno between 1 and 5 and v_puesto not in ('V-1', 'V-2', 'V-3', 'V-4') then v_puesto := null; end if;
  if v_es_vig and v_turno between 1 and 5 and v_puesto is null then raise exception 'Elige el puesto (V-1 a V-4).'; end if;
  v_completo := regexp_replace(trim(concat_ws(' ', v_nombre, nullif(trim(p->>'segundo_nombre'), ''), v_ap1, nullif(trim(p->>'apellido2'), ''))), '\s+', ' ', 'g');
  v_usuario := lower(trim(coalesce(nullif(p->>'usuario', ''), sugerir_usuario(v_nombre, v_ap1, p->>'apellido2', v_id))));
  if v_usuario is null or v_usuario !~ '^[a-z0-9]{3,}$' then raise exception 'El usuario solo puede tener letras y números (mínimo 3).'; end if;
  if exists (select 1 from cuentas where usuario = v_usuario and (v_id is null or persona_id is distinct from v_id)) then
    raise exception 'El usuario % ya lo tiene otra persona.', v_usuario;
  end if;
  if exists (select 1 from cuentas where correo = v_correo and (v_id is null or persona_id is distinct from v_id)) then
    raise exception 'El correo % ya lo tiene otra persona.', v_correo;
  end if;

  if v_id is null then
    v_id := gen_random_uuid();
    insert into personas (id, nombre, departamento_id, turno_numero, operador_indice, es_plaza_formacion, situacion, activo, puesto)
    values (v_id, v_completo, v_dep, v_turno, null, v_sit = 'bolsa', v_sit, true, v_puesto);
    perform _renumerar_operadores(v_dep, v_turno);
    if v_sit = 'titular' then perform _copiar_cuadrante(v_id, v_dep, v_turno, v_desde); end if;
  else
    select * into v_ant from personas where id = v_id for update;
    if not found then raise exception 'Esa persona no existe.'; end if;
    select correo into v_correo_ant from cuentas where persona_id = v_id;
    if v_correo_ant is not null and v_correo_ant <> v_correo
       and exists (select 1 from auth.users where lower(email) = v_correo_ant) then
      raise exception 'Esta persona ya activó su cuenta con %. El correo no se puede cambiar desde aquí.', v_correo_ant;
    end if;
    update personas set nombre = v_completo, es_plaza_formacion = (v_sit = 'bolsa'), situacion = v_sit,
                        departamento_id = v_dep, turno_numero = v_turno, puesto = v_puesto
     where id = v_id;
    if v_ant.departamento_id is distinct from v_dep or v_ant.turno_numero is distinct from v_turno or v_ant.situacion is distinct from v_sit then
      update personas set operador_indice = null where id = v_id;
      perform _renumerar_operadores(v_ant.departamento_id::int, v_ant.turno_numero::int);
      perform _renumerar_operadores(v_dep, v_turno);
      if v_sit = 'titular' then
        perform _copiar_cuadrante(v_id, v_dep, v_turno, v_cambio);            -- recibe el cuadrante de su turno desde la fecha indicada
      elsif v_ant.situacion = 'titular' then
        delete from cuadrante_dia where persona_id = v_id and fecha >= v_cambio and departamento_id is null;  -- deja de tener turno fijo
      end if;
    end if;
  end if;

  insert into fichas (persona_id, nombre, segundo_nombre, apellido1, apellido2, telefono, numero_empleado, fecha_incorporacion,
                      contacto_emergencia, telefono_emergencia, observaciones, actualizado_en)
  values (v_id, v_nombre, nullif(trim(p->>'segundo_nombre'), ''), v_ap1, nullif(trim(p->>'apellido2'), ''),
          nullif(trim(p->>'telefono'), ''), nullif(trim(p->>'numero_empleado'), ''), nullif(p->>'fecha_incorporacion', '')::date,
          nullif(trim(p->>'contacto_emergencia'), ''), nullif(trim(p->>'telefono_emergencia'), ''), nullif(trim(p->>'observaciones'), ''), now())
  on conflict (persona_id) do update set
    nombre = excluded.nombre, segundo_nombre = excluded.segundo_nombre, apellido1 = excluded.apellido1, apellido2 = excluded.apellido2,
    telefono = excluded.telefono, numero_empleado = excluded.numero_empleado, fecha_incorporacion = excluded.fecha_incorporacion,
    contacto_emergencia = excluded.contacto_emergencia, telefono_emergencia = excluded.telefono_emergencia,
    observaciones = excluded.observaciones, actualizado_en = now();

  if exists (select 1 from cuentas where persona_id = v_id) then
    update cuentas set usuario = v_usuario, correo = v_correo, nombre = v_completo, rol = v_rol, activo = true where persona_id = v_id;
  else
    insert into cuentas (usuario, correo, nombre, rol, persona_id) values (v_usuario, v_correo, v_completo, v_rol, v_id);
  end if;

  delete from habilitaciones where persona_id = v_id;
  insert into habilitaciones (persona_id, departamento_id)
  select v_id, d from unnest(v_hab) d where d <> v_dep and exists (select 1 from departamentos where id = d)
  on conflict do nothing;
  return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.horas_por_persona(p_anio integer DEFAULT 2026)
 RETURNS TABLE(persona_id uuid, mes integer, horas numeric, horas_hasta_hoy numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_column
declare v_ids uuid[];
begin
  if not public.es_admin() then return; end if;
  v_ids := public._personas_visibles();
  return query
  select x.persona_id, x.mes, sum(x.h)::numeric, (sum(x.h) filter (where x.fecha <= current_date))::numeric
  from (
    select c.persona_id, extract(month from c.fecha)::int as mes, c.fecha, coalesce(t.horas, 0)::numeric as h
    from cuadrante_dia c
    left join codigos_turno t on t.codigo = case when c.codigo = 'C' then 'F' else c.codigo end
    where c.fecha between make_date(p_anio, 1, 1) and make_date(p_anio, 12, 31) and c.persona_id = any(v_ids)
    union all
    select e.persona_id, extract(month from e.fecha)::int, e.fecha, e.horas
    from horas_extra e
    where e.fecha between make_date(p_anio, 1, 1) and make_date(p_anio, 12, 31) and e.persona_id = any(v_ids)
  ) x
  group by x.persona_id, x.mes;
end $function$
;

CREATE OR REPLACE FUNCTION public.lista_admins()
 RETURNS TABLE(usuario text, nombre text, correo text, activo boolean, cuenta_activada boolean, es_general boolean, soy_yo boolean, areas text[], mfa boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
  select c.usuario, c.nombre, c.correo, c.activo,
         exists (select 1 from auth.users u where lower(u.email) = c.correo and u.email_confirmed_at is not null),
         c.usuario = 'admin',
         c.correo = lower(auth.jwt() ->> 'email'),
         c.areas,
         exists (select 1 from auth.mfa_factors f join auth.users u on u.id = f.user_id
                  where lower(u.email) = c.correo and f.status = 'verified')
  from cuentas c
  where c.rol = 'admin' and c.persona_id is null and public._admin_total()
  order by c.usuario = 'admin' desc, c.activo desc, c.nombre;
$function$
;

CREATE OR REPLACE FUNCTION public.lista_personas()
 RETURNS TABLE(persona_id uuid, nombre_completo text, departamento_id integer, departamento text, turno_numero integer, operador_indice integer, es_plaza_formacion boolean, activo boolean, nombre text, segundo_nombre text, apellido1 text, apellido2 text, telefono text, numero_empleado text, fecha_incorporacion date, fecha_baja date, contacto_emergencia text, telefono_emergencia text, observaciones text, usuario text, correo text, rol text, cuenta_activada boolean, formacion_fin_prevista date, situacion text, habilitaciones integer[], nombre_corto text, categoria text, nombre_uso text, puesto text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
  select p.id, p.nombre, p.departamento_id::int, d.slug::text, p.turno_numero::int, p.operador_indice::int,
         coalesce(p.es_plaza_formacion, false), p.activo,
         f.nombre, f.segundo_nombre, f.apellido1, f.apellido2, f.telefono, f.numero_empleado,
         f.fecha_incorporacion, f.fecha_baja, f.contacto_emergencia, f.telefono_emergencia, f.observaciones,
         c.usuario, c.correo, c.rol,
         exists (select 1 from auth.users u where lower(u.email) = c.correo and u.email_confirmed_at is not null),
         f.formacion_fin_prevista, p.situacion,
         coalesce((select array_agg(h.departamento_id order by h.departamento_id) from habilitaciones h where h.persona_id = p.id), '{}'),
         p.nombre_corto, f.categoria, f.nombre_uso, p.puesto
  from personas p
  join departamentos d on d.id = p.departamento_id
  left join fichas f on f.persona_id = p.id
  left join cuentas c on c.persona_id = p.id
  where public.es_admin() and d.area = any(public.mis_areas())
  order by d.id, p.situacion desc, p.turno_numero nulls last, p.operador_indice nulls first, p.nombre;
$function$
;

CREATE OR REPLACE FUNCTION public.mi_cuenta()
 RETURNS TABLE(usuario text, nombre text, rol text, persona_id uuid, departamento text, turno_numero integer, operador_indice integer, areas text[], area text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select c.usuario, coalesce(nullif(p.nombre_corto, ''), c.nombre), c.rol, c.persona_id,
         d.slug::text, p.turno_numero::int, p.operador_indice::int, public.mis_areas(), d.area
  from cuentas c
  left join personas p on p.id = c.persona_id
  left join departamentos d on d.id = p.departamento_id
  where c.correo = lower(auth.jwt() ->> 'email') and c.activo
  limit 1;
$function$
;

CREATE OR REPLACE FUNCTION public.mi_persona()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select persona_id from cuentas where correo = lower(auth.jwt() ->> 'email') and activo limit 1;
$function$
;

CREATE OR REPLACE FUNCTION public.mis_areas()
 RETURNS text[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case when c.rol = 'admin' and public._aal2() then coalesce(c.areas, array['centro_control', 'incidencias'])
              else coalesce(array(
                select d.area from personas p join departamentos d on d.id = p.departamento_id where p.id = c.persona_id
                union
                select d2.area from habilitaciones h join departamentos d2 on d2.id = h.departamento_id where h.persona_id = c.persona_id
              ), '{}') end
  from cuentas c where c.correo = lower(auth.jwt() ->> 'email') and c.activo limit 1;
$function$
;

CREATE OR REPLACE FUNCTION public.pasar_a_titular(p_persona uuid, p_turno integer, p_desde date)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v personas;
begin
  if not es_admin() then raise exception 'Solo el administrador.'; end if;
  select * into v from personas where id = p_persona and activo for update;
  if not found then raise exception 'Esa persona no está activa.'; end if;
  if p_turno is null or p_turno not between 1 and 5 then raise exception 'Elige el turno (1 a 5).'; end if;
  update personas set es_plaza_formacion = false, situacion = 'titular', turno_numero = p_turno, operador_indice = null where id = p_persona;
  perform _renumerar_operadores(v.departamento_id::int, v.turno_numero::int);
  perform _renumerar_operadores(v.departamento_id::int, p_turno);
  perform _copiar_cuadrante(p_persona, v.departamento_id::int, p_turno, coalesce(p_desde, current_date));
  update fichas set formacion_fin_prevista = coalesce(p_desde, current_date), actualizado_en = now() where persona_id = p_persona;
end $function$
;

CREATE OR REPLACE FUNCTION public.patron_cct(p_desde date, p_hasta date)
 RETURNS TABLE(turno integer, fecha date, codigo text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_column
declare v_hasta date;
begin
  if auth.uid() is null or not ('centro_control' = any(coalesce(public.mis_areas(), '{}'))) then return; end if;
  v_hasta := case when public.es_admin() then p_hasta else least(p_hasta, public._fecha_tope()) end;
  return query
  select t.turno_numero::int, t.fecha, t.codigo
  from (
    select p.turno_numero, c.fecha, c.codigo,
           row_number() over (partition by p.turno_numero, c.fecha order by count(*) desc, (c.codigo = 'L'), c.codigo) as rn
    from cuadrante_dia c
    join personas p on p.id = c.persona_id
    join departamentos d on d.id = p.departamento_id and d.slug = 'cct'
    where p.activo and p.operador_indice is not null and c.codigo <> 'V'
      and c.fecha between p_desde and v_hasta
    group by p.turno_numero, c.fecha, c.codigo
  ) t
  where t.rn = 1
  order by 2, 1;
end $function$
;

CREATE OR REPLACE FUNCTION public.pedir_cambio(p_companero uuid, p_fecha date, p_fecha_devolucion date, p_motivo text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_yo uuid := mi_persona();
  v_id bigint; v_msg text;
  c_s1 text; c_c1 text; c_s2 text; c_c2 text;
begin
  if v_yo is null then raise exception 'Tu cuenta no está vinculada a ninguna persona del cuadrante.'; end if;
  if p_companero is null or p_companero = v_yo then raise exception 'Elige un compañero.'; end if;
  if not _pueden_cambiarse(v_yo, p_companero) then
    raise exception 'Solo puedes cambiar con compañeros de tu departamento (o de otro en el que los dos podáis cubrir).';
  end if;
  if p_fecha is null or p_fecha_devolucion is null then raise exception 'Faltan los dos días del cambio.'; end if;
  if p_fecha = p_fecha_devolucion then raise exception 'Los dos días del cambio tienen que ser distintos.'; end if;
  v_msg := coalesce(_fallo_plazo(p_fecha), _fallo_plazo(p_fecha_devolucion));
  if v_msg is not null then raise exception '%', v_msg; end if;
  c_s1 := _codigo(v_yo, p_fecha);            c_c1 := _codigo(p_companero, p_fecha);
  c_s2 := _codigo(v_yo, p_fecha_devolucion); c_c2 := _codigo(p_companero, p_fecha_devolucion);
  if c_s1 = c_c1 then raise exception 'El primer día los dos tenéis el mismo turno (%): no hay nada que cambiar.', c_s1; end if;
  if c_s2 = c_c2 then raise exception 'El segundo día los dos tenéis el mismo turno (%): no hay nada que cambiar.', c_s2; end if;
  -- Descanso mínimo: cómo quedaría cada uno tras el cambio (con el horario del puesto que hará)
  v_msg := coalesce(_fallo_descanso(v_yo, array[p_fecha, p_fecha_devolucion], array[c_c1, c_c2],
                                    array[_puesto_dia(p_companero, p_fecha), _puesto_dia(p_companero, p_fecha_devolucion)]),
                    _fallo_descanso(p_companero, array[p_fecha, p_fecha_devolucion], array[c_s1, c_s2],
                                    array[_puesto_dia(v_yo, p_fecha), _puesto_dia(v_yo, p_fecha_devolucion)]));
  if v_msg is not null then raise exception '%', v_msg; end if;
  insert into solicitudes_cambio (tipo, solicitante_id, companero_id, fecha, fecha_devolucion, motivo, estado,
                                  codigo_solicitante_1, codigo_companero_1, codigo_solicitante_2, codigo_companero_2)
  values ('cambio', v_yo, p_companero, p_fecha, p_fecha_devolucion, nullif(trim(p_motivo), ''), 'pendiente_compañero',
          c_s1, c_c1, c_s2, c_c2)
  returning id into v_id;
  return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.pedir_cambio_horario(p_companero uuid, p_desde date, p_hasta date, p_motivo text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_yo uuid := mi_persona(); d date; ca text; cb text; v_dias jsonb := '[]'; v_f date[] := '{}'; v_a text[] := '{}'; v_b text[] := '{}';
  v_pa text[] := '{}'; v_pb text[] := '{}';
  v_msg text; v_id bigint; n int := 0;
begin
  if v_yo is null then raise exception 'Tu cuenta no está vinculada a ninguna persona del cuadrante.'; end if;
  if p_companero is null or p_companero = v_yo then raise exception 'Elige un compañero.'; end if;
  if not _pueden_cambiarse(v_yo, p_companero) then
    raise exception 'Solo puedes cambiar con compañeros de tu departamento (o de otro en el que los dos podáis cubrir).';
  end if;
  if p_desde is null or p_hasta is null or p_hasta < p_desde then raise exception 'Fechas no válidas.'; end if;
  if p_hasta - p_desde > 13 then raise exception 'Como mucho 14 días seguidos.'; end if;
  v_msg := coalesce(_fallo_plazo(p_desde), _fallo_plazo(p_hasta));
  if v_msg is not null then raise exception '%', v_msg; end if;
  d := p_desde;
  while d <= p_hasta loop
    ca := _codigo(v_yo, d); cb := _codigo(p_companero, d);
    v_dias := v_dias || jsonb_build_object('f', d, 'a', ca, 'b', cb);
    if ca <> cb then
      v_f := v_f || d; v_a := v_a || ca; v_b := v_b || cb; n := n + 1;
      v_pa := v_pa || _puesto_dia(v_yo, d); v_pb := v_pb || _puesto_dia(p_companero, d);
    end if;
    d := d + 1;
  end loop;
  if n = 0 then raise exception 'Esos días los dos tenéis lo mismo: no hay nada que cambiar.'; end if;
  -- Descanso obligatorio: cómo quedaría cada uno (con el horario del puesto que hará)
  v_msg := coalesce(_fallo_descanso(v_yo, v_f, v_b, v_pb), _fallo_descanso(p_companero, v_f, v_a, v_pa));
  if v_msg is not null then raise exception '%', v_msg; end if;
  insert into solicitudes_cambio (tipo, solicitante_id, companero_id, fecha, fecha_devolucion, motivo, estado, dias,
                                  codigo_solicitante_1, codigo_companero_1)
  values ('horario', v_yo, p_companero, p_desde, p_hasta, nullif(trim(p_motivo), ''), 'pendiente_compañero', v_dias,
          _codigo(v_yo, p_desde), _codigo(p_companero, p_desde))
  returning id into v_id;
  return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.pedir_cambio_movilidad(p_companero uuid, p_desde date, p_hasta date, p_dggvc uuid, p_motivo text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_yo uuid := mi_persona(); yo personas; el personas; d date; c1 text; c2 text; v_id bigint;
begin
  if v_yo is null then raise exception 'Tu cuenta no está vinculada a ninguna persona del cuadrante.'; end if;
  select * into yo from personas where id = v_yo;
  select * into el from personas where id = p_companero and activo;
  if el.id is null or el.id = v_yo then raise exception 'Elige un compañero.'; end if;
  if (select slug from departamentos where id = yo.departamento_id) <> 'cct' or yo.departamento_id is distinct from el.departamento_id then
    raise exception 'El puesto de Movilidad solo se puede cambiar con un compañero de Centro de Control.';
  end if;
  if p_dggvc not in (v_yo, p_companero) then raise exception 'Solicitud no válida.'; end if;
  if p_desde is null or p_hasta is null or p_hasta < p_desde then raise exception 'Fechas no válidas.'; end if;
  if p_desde < current_date then raise exception 'No se pueden cambiar días que ya han pasado.'; end if;
  if p_hasta - p_desde > 13 then raise exception 'Como mucho 14 días seguidos.'; end if;
  d := p_desde;
  while d <= p_hasta loop
    c1 := _codigo(v_yo, d); c2 := _codigo(p_companero, d);
    if c1 = 'L' or c1 <> c2 then raise exception 'Los dos tenéis que estar trabajando en el mismo horario todos esos días.'; end if;
    d := d + 1;
  end loop;
  insert into solicitudes_cambio (tipo, solicitante_id, companero_id, fecha, fecha_devolucion, motivo, estado,
                                  movilidad_dggvc, codigo_solicitante_1, codigo_companero_1)
  values ('movilidad', v_yo, p_companero, p_desde, p_hasta, nullif(trim(p_motivo), ''), 'pendiente_compañero',
          p_dggvc, _codigo(v_yo, p_desde), _codigo(p_companero, p_desde))
  returning id into v_id;
  return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.pedir_dia_libre(p_fecha date, p_motivo text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_yo uuid := mi_persona();
  v_id bigint;
  c_s1 text;
begin
  if v_yo is null then raise exception 'Tu cuenta no está vinculada a ninguna persona del cuadrante.'; end if;
  if p_fecha is null or p_fecha < current_date then raise exception 'Elige un día que no haya pasado.'; end if;
  c_s1 := _codigo(v_yo, p_fecha);
  if c_s1 = 'L' then raise exception 'Ese día ya lo tienes libre.'; end if;
  insert into solicitudes_cambio (tipo, solicitante_id, fecha, motivo, estado, codigo_solicitante_1)
  values ('dia_libre', v_yo, p_fecha, nullif(trim(p_motivo), ''), 'pendiente_admin', c_s1)
  returning id into v_id;
  return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.publicar_anio(p_area text, p_anio integer, p_publicar boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_admin text;
begin
  if not es_admin() then raise exception 'Solo un administrador puede publicar el cuadrante.'; end if;
  if not (p_area = any(mis_areas())) then raise exception 'Esa área no es tuya.'; end if;
  if p_anio <= extract(year from current_date)::int then raise exception 'Ese año ya es visible: es el año en curso o uno pasado.'; end if;
  select usuario into v_admin from cuentas where correo = lower(auth.jwt() ->> 'email');
  if p_publicar then
    insert into anios_publicados (area, anio, publicado_por) values (p_area, p_anio, v_admin) on conflict do nothing;
  else
    delete from anios_publicados where area = p_area and anio = p_anio;
  end if;
end $function$
;

CREATE OR REPLACE FUNCTION public.quitar_de_turno(p_persona uuid, p_fecha date, p_tipo text, p_sustituto uuid DEFAULT NULL::uuid, p_motivo text DEFAULT NULL::text, p_solape_m uuid DEFAULT NULL::uuid, p_solape_n uuid DEFAULT NULL::uuid)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v personas; v_cod text; v_dep int; v_admin text; v_id bigint; v_pu text;
begin
  if not es_admin() then raise exception 'Solo el administrador puede editar el cuadrante.'; end if;
  select * into v from personas where id = p_persona;
  if not found then raise exception 'Esa persona no existe.'; end if;
  v_cod := _codigo(p_persona, p_fecha);
  v_dep := coalesce((select departamento_id from cuadrante_dia where persona_id = p_persona and fecha = p_fecha), v.departamento_id);
  v_pu := _puesto_dia(p_persona, p_fecha);
  if v_cod = 'L' then raise exception 'Ese día ya está libre: no hay nada que quitar.'; end if;
  if p_tipo not in ('no_cubrir', 'vacante', 'solape', 'cubierto') then raise exception 'Opción no válida.'; end if;
  if p_tipo = 'solape' and v_cod <> 'T' then raise exception 'El solape solo es para el turno de tarde.'; end if;
  if p_tipo = 'cubierto' then
    if p_sustituto is null or p_sustituto = p_persona then raise exception 'Elige quién cubre el turno.'; end if;
    if not exists (select 1 from personas where id = p_sustituto and activo) then raise exception 'Esa persona no está activa.'; end if;
    perform _poner_codigo_en(p_sustituto, p_fecha, v_cod, v_dep);
    perform _dar_puesto(p_sustituto, p_fecha, v_pu);
  end if;
  perform _poner_codigo(p_persona, p_fecha, 'L');
  select usuario into v_admin from cuentas where correo = lower(auth.jwt() ->> 'email');
  insert into huecos (fecha, departamento_id, turno_numero, codigo, persona_quitada, tipo, estado, cubierto_por, motivo, creado_por, puesto)
  values (p_fecha, v_dep, v.turno_numero, v_cod, p_persona, p_tipo,
          case p_tipo when 'vacante' then 'abierto' when 'cubierto' then 'cubierto' else 'cerrado' end,
          case when p_tipo = 'cubierto' then p_sustituto end, nullif(trim(p_motivo), ''), v_admin, v_pu)
  returning id into v_id;
  if p_tipo = 'solape' then
    if p_solape_m is not null then
      insert into horas_extra (persona_id, fecha, tipo, horas, nota, hueco_id, creado_por)
      values (p_solape_m, p_fecha, 'solape', 4, 'Amplía la mañana (solape de tarde)', v_id, v_admin);
    end if;
    if p_solape_n is not null then
      insert into horas_extra (persona_id, fecha, tipo, horas, nota, hueco_id, creado_por)
      values (p_solape_n, p_fecha, 'solape', 4, 'Entra 4 h antes de noche (solape de tarde)', v_id, v_admin);
    end if;
  end if;
  return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.quitar_mfa(p_usuario text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare c cuentas; n int;
begin
  if not _admin_total() then raise exception 'Solo el administrador general puede hacer esto.'; end if;
  select * into c from cuentas where usuario = lower(trim(p_usuario)) and rol = 'admin';
  if not found then raise exception 'Ese administrador no existe.'; end if;
  if c.correo = lower(auth.jwt() ->> 'email') then raise exception 'No puedes reiniciar tu propia verificación desde aquí.'; end if;
  delete from auth.mfa_factors where user_id in (select id from auth.users where lower(email) = c.correo);
  get diagnostics n = row_count;
  return n;
end $function$
;

CREATE OR REPLACE FUNCTION public.reactivar_persona(p_persona uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v personas;
begin
  if not es_admin() then raise exception 'Solo el administrador puede reactivar.'; end if;
  select * into v from personas where id = p_persona for update;
  update personas set activo = true, operador_indice = null where id = p_persona;
  update fichas set fecha_baja = null, actualizado_en = now() where persona_id = p_persona;
  update cuentas set activo = true where persona_id = p_persona;
  perform _renumerar_operadores(v.departamento_id::int, v.turno_numero::int);
end $function$
;

CREATE OR REPLACE FUNCTION public.resolver_solicitud(p_id bigint, p_aprueba boolean, p_movilidad jsonb DEFAULT NULL::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare s solicitudes_cambio; v_admin text; h huecos; x jsonb;
begin
  if not es_admin() then raise exception 'Solo el administrador puede resolver solicitudes.'; end if;
  select usuario into v_admin from cuentas where correo = lower(auth.jwt() ->> 'email');
  select * into s from solicitudes_cambio where id = p_id for update;
  if not found then raise exception 'La solicitud no existe.'; end if;
  if s.estado <> 'pendiente_admin' then raise exception 'Esta solicitud no está pendiente de aprobación.'; end if;
  if p_aprueba then
    if s.tipo = 'horario' then
      perform _aplicar_horario(s, p_movilidad);
    else
      if _codigo(s.solicitante_id, s.fecha) <> s.codigo_solicitante_1
         or (s.tipo = 'cambio' and (_codigo(s.companero_id, s.fecha) <> s.codigo_companero_1
                                 or _codigo(s.solicitante_id, s.fecha_devolucion) <> s.codigo_solicitante_2
                                 or _codigo(s.companero_id, s.fecha_devolucion) <> s.codigo_companero_2)) then
        raise exception 'El cuadrante de esos días ha cambiado desde que se pidió. Rechaza la solicitud y que la vuelvan a pedir.';
      end if;
      if s.tipo = 'dia_libre' then
        perform _poner_codigo(s.solicitante_id, s.fecha, 'L');
      elsif s.tipo = 'vacante' then
        select * into h from huecos where id = s.hueco_id for update;
        if not found or h.estado <> 'abierto' then raise exception 'Esa vacante ya no está abierta.'; end if;
        perform _poner_codigo_en(s.solicitante_id, s.fecha, h.codigo, h.departamento_id);
        perform _dar_puesto(s.solicitante_id, s.fecha, h.puesto);          -- hace el puesto de quien dejó la vacante
        update huecos set estado = 'cubierto', cubierto_por = s.solicitante_id where id = h.id;
        update solicitudes_cambio set estado = 'rechazado_admin', resuelto_en = now(), resuelto_por_usuario = v_admin
         where hueco_id = h.id and id <> s.id and estado = 'pendiente_admin';
      else
        perform set_config('app.motivo', 'cambio', true);
        perform _cambiar_dia(s.solicitante_id, s.companero_id, s.fecha,            s.codigo_companero_1, s.codigo_solicitante_1);
        perform _cambiar_dia(s.solicitante_id, s.companero_id, s.fecha_devolucion, s.codigo_companero_2, s.codigo_solicitante_2);
        perform set_config('app.motivo', '', true);
      end if;
      if s.tipo = 'cambio' and p_movilidad is not null then
        for x in select value from jsonb_array_elements(p_movilidad) loop
          if (x->>'persona')::uuid not in (s.solicitante_id, s.companero_id) then continue; end if;
          delete from movilidad_cambios where fecha = (x->>'fecha')::date and persona_dggvc = (x->>'persona')::uuid and turno_numero <> (x->>'turno')::int;
          insert into movilidad_cambios (turno_numero, fecha, persona_dggvc, solicitud_id)
          values ((x->>'turno')::int, (x->>'fecha')::date, (x->>'persona')::uuid, s.id)
          on conflict (turno_numero, fecha) do update set persona_dggvc = excluded.persona_dggvc, solicitud_id = excluded.solicitud_id, creado_en = now();
        end loop;
      end if;
    end if;
  end if;
  update solicitudes_cambio
     set estado = case when p_aprueba then 'aprobado' else 'rechazado_admin' end::estado_cambio,
         resuelto_en = now(), resuelto_por_usuario = v_admin
   where id = p_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.responder_solicitud(p_id bigint, p_acepta boolean, p_movilidad jsonb DEFAULT NULL::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare s solicitudes_cambio; d date; v_quien text; v_sale uuid; v_turno int; v_msg text; x jsonb;
begin
  select * into s from solicitudes_cambio where id = p_id for update;
  if not found or s.companero_id is distinct from mi_persona() then raise exception 'Esta solicitud no es para ti.'; end if;
  if s.estado <> 'pendiente_compañero' then raise exception 'Esta solicitud ya no está esperando tu respuesta.'; end if;
  select usuario into v_quien from cuentas where persona_id = s.companero_id;

  if s.tipo = 'movilidad' then
    if p_acepta then
      v_sale := case when s.movilidad_dggvc = s.solicitante_id then s.companero_id else s.solicitante_id end;
      d := s.fecha;
      while d <= s.fecha_devolucion loop
        v_turno := _puesto_movilidad(v_sale, d);
        delete from movilidad_cambios where fecha = d and persona_dggvc = s.movilidad_dggvc and turno_numero <> v_turno;
        insert into movilidad_cambios (turno_numero, fecha, persona_dggvc, solicitud_id)
        values (v_turno, d, s.movilidad_dggvc, s.id)
        on conflict (turno_numero, fecha) do update set persona_dggvc = excluded.persona_dggvc, solicitud_id = excluded.solicitud_id, creado_en = now();
        d := d + 1;
      end loop;
    end if;
    update solicitudes_cambio set estado = case when p_acepta then 'aprobado' else 'rechazado_compañero' end::estado_cambio,
           resuelto_en = now(), resuelto_por_usuario = v_quien where id = p_id;
    return;
  end if;

  if not p_acepta then
    update solicitudes_cambio set estado = 'rechazado_compañero', resuelto_en = now(), resuelto_por_usuario = v_quien where id = p_id;
    return;
  end if;

  -- Con menos de 5 días de antelación: lo tiene que aprobar el admin
  if s.tipo in ('cambio', 'horario') and least(s.fecha, coalesce(s.fecha_devolucion, s.fecha)) < current_date + 5 then
    if least(s.fecha, coalesce(s.fecha_devolucion, s.fecha)) < current_date then raise exception 'Uno de los días del cambio ya ha pasado.'; end if;
    update solicitudes_cambio set estado = 'pendiente_admin', resuelto_en = null where id = p_id;
    return;
  end if;

  if s.tipo = 'horario' then
    perform _aplicar_horario(s, p_movilidad);
    update solicitudes_cambio set estado = 'aprobado', resuelto_en = now(), resuelto_por_usuario = 'automático' where id = p_id;
    return;
  end if;

  if s.tipo = 'cambio' then
    if _codigo(s.solicitante_id, s.fecha) <> s.codigo_solicitante_1 or _codigo(s.companero_id, s.fecha) <> s.codigo_companero_1
       or _codigo(s.solicitante_id, s.fecha_devolucion) <> s.codigo_solicitante_2 or _codigo(s.companero_id, s.fecha_devolucion) <> s.codigo_companero_2 then
      raise exception 'El cuadrante de esos días ha cambiado desde que se pidió. Rechaza este cambio y que lo vuelvan a pedir.';
    end if;
    v_msg := coalesce(_fallo_descanso(s.solicitante_id, array[s.fecha, s.fecha_devolucion], array[s.codigo_companero_1, s.codigo_companero_2],
                                      array[_puesto_dia(s.companero_id, s.fecha), _puesto_dia(s.companero_id, s.fecha_devolucion)]),
                      _fallo_descanso(s.companero_id,   array[s.fecha, s.fecha_devolucion], array[s.codigo_solicitante_1, s.codigo_solicitante_2],
                                      array[_puesto_dia(s.solicitante_id, s.fecha), _puesto_dia(s.solicitante_id, s.fecha_devolucion)]));
    if v_msg is not null then raise exception '%', v_msg; end if;
    perform set_config('app.motivo', 'cambio', true);
    perform _cambiar_dia(s.solicitante_id, s.companero_id, s.fecha,            s.codigo_companero_1, s.codigo_solicitante_1);
    perform _cambiar_dia(s.solicitante_id, s.companero_id, s.fecha_devolucion, s.codigo_companero_2, s.codigo_solicitante_2);
    perform set_config('app.motivo', '', true);
    if p_movilidad is not null then
      for x in select value from jsonb_array_elements(p_movilidad) loop
        if (x->>'persona')::uuid not in (s.solicitante_id, s.companero_id)
           or (x->>'fecha')::date not in (s.fecha, s.fecha_devolucion) then continue; end if;
        delete from movilidad_cambios where fecha = (x->>'fecha')::date and persona_dggvc = (x->>'persona')::uuid and turno_numero <> (x->>'turno')::int;
        insert into movilidad_cambios (turno_numero, fecha, persona_dggvc, solicitud_id)
        values ((x->>'turno')::int, (x->>'fecha')::date, (x->>'persona')::uuid, s.id)
        on conflict (turno_numero, fecha) do update set persona_dggvc = excluded.persona_dggvc, solicitud_id = excluded.solicitud_id, creado_en = now();
      end loop;
    end if;
    update solicitudes_cambio set estado = 'aprobado', resuelto_en = now(), resuelto_por_usuario = 'automático' where id = p_id;
    return;
  end if;

  update solicitudes_cambio set estado = 'pendiente_admin', resuelto_en = null where id = p_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.solicitar_vacante(p_hueco bigint, p_motivo text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_yo uuid := mi_persona(); h huecos; v_id bigint; v_msg text;
begin
  if v_yo is null then raise exception 'Tu cuenta no está vinculada a ninguna persona del cuadrante.'; end if;
  select * into h from huecos where id = p_hueco;
  if not found or h.tipo <> 'vacante' or h.estado <> 'abierto' then raise exception 'Esa vacante ya no está disponible.'; end if;
  if h.fecha < current_date then raise exception 'Esa vacante es de un día que ya ha pasado.'; end if;
  if (select departamento_id from personas where id = v_yo) is distinct from h.departamento_id
     and not exists (select 1 from habilitaciones where persona_id = v_yo and departamento_id = h.departamento_id) then
    raise exception 'Esa vacante es de un departamento en el que no puedes cubrir.';
  end if;
  if _codigo(v_yo, h.fecha) <> 'L' then raise exception 'Solo puedes pedir una vacante un día que tengas libre.'; end if;
  v_msg := _fallo_descanso(v_yo, array[h.fecha], array[h.codigo], array[h.puesto]);
  if v_msg is not null then raise exception '%', v_msg; end if;
  if exists (select 1 from solicitudes_cambio where hueco_id = p_hueco and solicitante_id = v_yo and estado = 'pendiente_admin') then
    raise exception 'Ya has solicitado esta vacante.';
  end if;
  insert into solicitudes_cambio (tipo, solicitante_id, fecha, motivo, estado, hueco_id, codigo_solicitante_1, codigo_companero_1)
  values ('vacante', v_yo, h.fecha, nullif(trim(p_motivo), ''), 'pendiente_admin', p_hueco, 'L', h.codigo)
  returning id into v_id;
  return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.sugerir_usuario(p_nombre text, p_apellido1 text, p_apellido2 text, p_persona uuid DEFAULT NULL::uuid)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare base text; cand text; n int := 1;
begin
  base := left(_letras(p_nombre), 1) || _letras(p_apellido1) || left(_letras(p_apellido2), 1);
  if length(base) < 2 then return null; end if;
  cand := base;
  while exists (select 1 from cuentas where usuario = cand and (p_persona is null or persona_id is distinct from p_persona)) loop
    n := n + 1; cand := base || n;
  end loop;
  return cand;
end $function$
;

-- =====================================================================
-- 9. AUTOMATISMOS (triggers)
-- Registro de cambios, avisos por correo, reglas de las solicitudes (un día una solicitud, mismas horas, sin vacaciones),
-- nombre corto de cada persona y el guardián de áreas (solo_mi_area: un administrador solo puede cambiar lo de sus áreas).
-- =====================================================================
CREATE TRIGGER admin_de_su_area BEFORE INSERT OR UPDATE ON public.cuentas FOR EACH ROW EXECUTE FUNCTION _admin_de_su_area();
CREATE TRIGGER avisar_solicitud AFTER INSERT OR UPDATE OF estado ON public.solicitudes_cambio FOR EACH ROW WHEN ((COALESCE(current_setting('app.sin_aviso'::text, true), ''::text) <> 'on'::text)) EXECUTE FUNCTION _avisar_solicitud();
CREATE TRIGGER cuadrante_dia_limpiar_nota BEFORE UPDATE OF codigo ON public.cuadrante_dia FOR EACH ROW EXECUTE FUNCTION _limpiar_nota_dia();
CREATE TRIGGER cuadrante_dia_registro AFTER INSERT OR DELETE OR UPDATE ON public.cuadrante_dia FOR EACH ROW EXECUTE FUNCTION _registrar_cuadrante();
CREATE TRIGGER fichas_nombre_corto AFTER INSERT OR UPDATE OF nombre, apellido1, nombre_uso ON public.fichas FOR EACH ROW EXECUTE FUNCTION _actualizar_nombre_corto();
CREATE TRIGGER horas_extra_registro AFTER INSERT OR DELETE OR UPDATE ON public.horas_extra FOR EACH ROW EXECUTE FUNCTION _registrar_horas();
CREATE TRIGGER mismas_horas BEFORE INSERT ON public.solicitudes_cambio FOR EACH ROW EXECUTE FUNCTION _mismas_horas();
CREATE TRIGGER sin_vacaciones BEFORE INSERT ON public.solicitudes_cambio FOR EACH ROW EXECUTE FUNCTION _sin_vacaciones();
CREATE TRIGGER solo_anios_publicados BEFORE INSERT ON public.solicitudes_cambio FOR EACH ROW EXECUTE FUNCTION _solo_anios_publicados();
CREATE TRIGGER solo_mi_area BEFORE INSERT OR DELETE OR UPDATE ON public.cuadrante_dia FOR EACH ROW EXECUTE FUNCTION _solo_mi_area('persona_id');
CREATE TRIGGER solo_mi_area BEFORE INSERT OR DELETE OR UPDATE ON public.cuentas FOR EACH ROW EXECUTE FUNCTION _solo_mi_area('persona_id');
CREATE TRIGGER solo_mi_area BEFORE INSERT OR DELETE OR UPDATE ON public.fichas FOR EACH ROW EXECUTE FUNCTION _solo_mi_area('persona_id');
CREATE TRIGGER solo_mi_area BEFORE INSERT OR DELETE OR UPDATE ON public.habilitaciones FOR EACH ROW EXECUTE FUNCTION _solo_mi_area('persona_id');
CREATE TRIGGER solo_mi_area BEFORE INSERT OR DELETE OR UPDATE ON public.horas_extra FOR EACH ROW EXECUTE FUNCTION _solo_mi_area('persona_id');
CREATE TRIGGER solo_mi_area BEFORE INSERT OR DELETE OR UPDATE ON public.huecos FOR EACH ROW EXECUTE FUNCTION _solo_mi_area('-');
CREATE TRIGGER solo_mi_area BEFORE INSERT OR DELETE OR UPDATE ON public.movilidad_cambios FOR EACH ROW EXECUTE FUNCTION _solo_mi_area('cct');
CREATE TRIGGER solo_mi_area BEFORE INSERT OR DELETE OR UPDATE ON public.patrones FOR EACH ROW EXECUTE FUNCTION _solo_mi_area('-');
CREATE TRIGGER solo_mi_area BEFORE INSERT OR DELETE OR UPDATE ON public.personas FOR EACH ROW EXECUTE FUNCTION _solo_mi_area('-');
CREATE TRIGGER solo_mi_area BEFORE INSERT OR DELETE OR UPDATE ON public.puestos FOR EACH ROW EXECUTE FUNCTION _solo_mi_area('-');
CREATE TRIGGER solo_mi_area BEFORE INSERT OR DELETE OR UPDATE ON public.solicitudes_cambio FOR EACH ROW EXECUTE FUNCTION _solo_mi_area('solicitante_id');
CREATE TRIGGER un_dia_una_solicitud BEFORE INSERT ON public.solicitudes_cambio FOR EACH ROW EXECUTE FUNCTION _un_dia_una_solicitud();

-- Automatismos sobre las cuentas de acceso (están en el esquema auth: se añaden aparte)
-- · Solo puede activar su acceso quien tenga una cuenta dada de alta en la app
drop trigger if exists solo_cuentas_dadas_de_alta on auth.users;
create trigger solo_cuentas_dadas_de_alta before insert on auth.users for each row execute function public._solo_cuentas_dadas_de_alta();
-- · Historial de contraseñas (las 15 últimas, para no repetirlas) y fecha del último cambio (caducidad a los 90 días)
drop trigger if exists guardar_clave_historial on auth.users;
create trigger guardar_clave_historial after insert or update of encrypted_password on auth.users for each row execute function public._guardar_clave_historial();

-- =====================================================================
-- 10. SEGURIDAD POR FILAS (RLS)
-- Sin sesión no se ve nada. Con sesión, cada regla de abajo dice quién puede ver o cambiar qué.
-- =====================================================================
alter table public.anios_publicados enable row level security;
alter table public.codigos_turno enable row level security;
alter table public.cuadrante_dia enable row level security;
alter table public.cuentas enable row level security;
alter table public.departamentos enable row level security;
alter table public.festivos enable row level security;
alter table public.fichas enable row level security;
alter table public.habilitaciones enable row level security;
alter table public.historial_claves enable row level security;
alter table public.horas_extra enable row level security;
alter table public.huecos enable row level security;
alter table public.movilidad_cambios enable row level security;
alter table public.patrones enable row level security;
alter table public.personas enable row level security;
alter table public.puestos enable row level security;
alter table public.registro_cuadrante enable row level security;
alter table public.solicitudes_cambio enable row level security;

-- =====================================================================
-- 11. REGLAS DE ACCESO (políticas)
-- =====================================================================
create policy "leer con sesion" on public.anios_publicados as PERMISSIVE for SELECT to authenticated using (true);
create policy "admin modifica" on public.codigos_turno as PERMISSIVE for ALL to authenticated using (es_admin()) with check (es_admin());
create policy "leer con sesion" on public.codigos_turno as PERMISSIVE for SELECT to authenticated using (true);
create policy "admin modifica" on public.cuadrante_dia as PERMISSIVE for ALL to authenticated using ((es_admin() AND (persona_id IN ( SELECT unnest(_personas_visibles()) AS unnest)))) with check ((es_admin() AND (persona_id IN ( SELECT unnest(_personas_visibles()) AS unnest))));
create policy "leer con sesion" on public.cuadrante_dia as PERMISSIVE for SELECT to authenticated using (((persona_id IN ( SELECT unnest(_personas_visibles()) AS unnest)) AND (( SELECT es_admin() AS es_admin) OR (fecha <= ( SELECT _fecha_tope() AS _fecha_tope)))));
create policy "admin gestiona cuentas" on public.cuentas as PERMISSIVE for ALL to authenticated using (((es_admin() AND (persona_id IN ( SELECT unnest(_personas_visibles()) AS unnest))) OR _admin_total())) with check (((es_admin() AND (persona_id IN ( SELECT unnest(_personas_visibles()) AS unnest))) OR _admin_total()));
create policy "ver mi cuenta" on public.cuentas as PERMISSIVE for SELECT to authenticated using (((correo = lower((auth.jwt() ->> 'email'::text))) OR (es_admin() AND (persona_id IN ( SELECT unnest(_personas_visibles()) AS unnest))) OR _admin_total()));
create policy "admin modifica" on public.departamentos as PERMISSIVE for ALL to authenticated using (es_admin()) with check (es_admin());
create policy "leer con sesion" on public.departamentos as PERMISSIVE for SELECT to authenticated using ((id IN ( SELECT unnest(_deps_visibles()) AS unnest)));
create policy "admin modifica" on public.festivos as PERMISSIVE for ALL to authenticated using (es_admin()) with check (es_admin());
create policy "leer con sesion" on public.festivos as PERMISSIVE for SELECT to authenticated using (true);
create policy "admin gestiona fichas" on public.fichas as PERMISSIVE for ALL to authenticated using ((es_admin() AND (persona_id IN ( SELECT unnest(_personas_visibles()) AS unnest)))) with check ((es_admin() AND (persona_id IN ( SELECT unnest(_personas_visibles()) AS unnest))));
create policy "ver mi ficha o admin" on public.fichas as PERMISSIVE for SELECT to authenticated using (((persona_id = mi_persona()) OR (es_admin() AND (persona_id IN ( SELECT unnest(_personas_visibles()) AS unnest)))));
create policy "admin gestiona" on public.habilitaciones as PERMISSIVE for ALL to authenticated using ((es_admin() AND (persona_id IN ( SELECT unnest(_personas_visibles()) AS unnest)))) with check ((es_admin() AND (persona_id IN ( SELECT unnest(_personas_visibles()) AS unnest))));
create policy "ver las mias o admin" on public.habilitaciones as PERMISSIVE for SELECT to authenticated using (((persona_id = mi_persona()) OR (es_admin() AND (persona_id IN ( SELECT unnest(_personas_visibles()) AS unnest)))));
create policy "admin gestiona" on public.horas_extra as PERMISSIVE for ALL to authenticated using ((es_admin() AND (persona_id IN ( SELECT unnest(_personas_visibles()) AS unnest)))) with check ((es_admin() AND (persona_id IN ( SELECT unnest(_personas_visibles()) AS unnest))));
create policy "ver las mias o admin" on public.horas_extra as PERMISSIVE for SELECT to authenticated using ((((persona_id = mi_persona()) AND (fecha <= ( SELECT _fecha_tope() AS _fecha_tope))) OR (es_admin() AND (persona_id IN ( SELECT unnest(_personas_visibles()) AS unnest)))));
create policy "leer con sesion" on public.huecos as PERMISSIVE for SELECT to authenticated using (((departamento_id IN ( SELECT unnest(_deps_visibles()) AS unnest)) AND (( SELECT es_admin() AS es_admin) OR (fecha <= ( SELECT _fecha_tope() AS _fecha_tope)))));
create policy "admin modifica" on public.movilidad_cambios as PERMISSIVE for ALL to authenticated using ((es_admin() AND ('centro_control'::text IN ( SELECT unnest(mis_areas()) AS unnest)))) with check ((es_admin() AND ('centro_control'::text IN ( SELECT unnest(mis_areas()) AS unnest))));
create policy "leer con sesion" on public.movilidad_cambios as PERMISSIVE for SELECT to authenticated using (('centro_control'::text IN ( SELECT unnest(mis_areas()) AS unnest)));
create policy "admin modifica" on public.patrones as PERMISSIVE for ALL to authenticated using ((es_admin() AND (departamento_id IN ( SELECT unnest(_deps_visibles()) AS unnest)))) with check ((es_admin() AND (departamento_id IN ( SELECT unnest(_deps_visibles()) AS unnest))));
create policy "leer con sesion" on public.patrones as PERMISSIVE for SELECT to authenticated using ((departamento_id IN ( SELECT unnest(_deps_visibles()) AS unnest)));
create policy "admin modifica" on public.personas as PERMISSIVE for ALL to authenticated using ((es_admin() AND (departamento_id IN ( SELECT unnest(_deps_visibles()) AS unnest)))) with check ((es_admin() AND (departamento_id IN ( SELECT unnest(_deps_visibles()) AS unnest))));
create policy "leer con sesion" on public.personas as PERMISSIVE for SELECT to authenticated using ((departamento_id IN ( SELECT unnest(_deps_visibles()) AS unnest)));
create policy "admin modifica" on public.puestos as PERMISSIVE for ALL to authenticated using ((es_admin() AND (departamento_id IN ( SELECT unnest(_deps_visibles()) AS unnest)))) with check ((es_admin() AND (departamento_id IN ( SELECT unnest(_deps_visibles()) AS unnest))));
create policy "leer con sesion" on public.puestos as PERMISSIVE for SELECT to authenticated using ((departamento_id IN ( SELECT unnest(_deps_visibles()) AS unnest)));
create policy "solo admin lee" on public.registro_cuadrante as PERMISSIVE for SELECT to authenticated using ((es_admin() AND (persona_id IN ( SELECT unnest(_personas_visibles()) AS unnest))));
create policy "admin borra solicitudes" on public.solicitudes_cambio as PERMISSIVE for DELETE to authenticated using (es_admin());
create policy "solo admin escribe" on public.solicitudes_cambio as PERMISSIVE for INSERT to authenticated with check (es_admin());
create policy "solo admin modifica" on public.solicitudes_cambio as PERMISSIVE for UPDATE to authenticated using (es_admin()) with check (es_admin());
create policy "ver mis solicitudes" on public.solicitudes_cambio as PERMISSIVE for SELECT to authenticated using (((solicitante_id = mi_persona()) OR (companero_id = mi_persona()) OR (es_admin() AND (solicitante_id IN ( SELECT unnest(_personas_visibles()) AS unnest)))));

-- =====================================================================
-- 12. QUIÉN PUEDE LLAMAR A CADA FUNCIÓN
-- Sin sesión (anon) solo correo_de_usuario (la pantalla de acceso). Las internas (_) no se pueden llamar desde fuera.
-- Supabase da permiso a 'anon' en cada función nueva: por eso se cierran todas aquí y se cambia el valor por defecto.
-- =====================================================================
revoke execute on function public._aal2() from public, anon, authenticated; grant execute on function public._aal2() to authenticated;
revoke execute on function public._actualizar_nombre_corto() from public, anon, authenticated;
revoke execute on function public._admin_de_su_area() from public, anon, authenticated;
revoke execute on function public._admin_total() from public, anon, authenticated; grant execute on function public._admin_total() to authenticated;
revoke execute on function public._aplicar_horario(s solicitudes_cambio, p_movilidad jsonb) from public, anon, authenticated;
revoke execute on function public._avisar_solicitud() from public, anon, authenticated;
revoke execute on function public._cambiar_dia(p_a uuid, p_b uuid, p_fecha date, p_cod_a text, p_cod_b text, p_departamento integer) from public, anon, authenticated;
revoke execute on function public._clave_caducada(p_user uuid) from public, anon, authenticated;
revoke execute on function public._clave_en_historial(p_user uuid, p_clave text) from public, anon, authenticated;
revoke execute on function public._codigo(p_persona uuid, p_fecha date) from public, anon, authenticated;
revoke execute on function public._codigo_correo(p text) from public, anon, authenticated;
revoke execute on function public._copiar_cuadrante(p_persona uuid, p_departamento integer, p_turno integer, p_desde date) from public, anon, authenticated;
revoke execute on function public._correo_persona(p uuid) from public, anon, authenticated;
revoke execute on function public._dar_puesto(p_persona uuid, p_fecha date, p_puesto text) from public, anon, authenticated;
revoke execute on function public._dep_dia(p_persona uuid, p_fecha date) from public, anon, authenticated;
revoke execute on function public._deps_visibles() from public, anon, authenticated; grant execute on function public._deps_visibles() to authenticated;
revoke execute on function public._dias_solicitud(s solicitudes_cambio) from public, anon, authenticated;
revoke execute on function public._enviar_correo(p_para text, p_asunto text, p_lineas text[]) from public, anon, authenticated;
revoke execute on function public._fallo_descanso(p_persona uuid, p_fechas date[], p_codigos text[], p_puestos text[]) from public, anon, authenticated;
revoke execute on function public._fallo_plazo(p_fecha date) from public, anon, authenticated;
revoke execute on function public._fecha_correo(p date) from public, anon, authenticated;
revoke execute on function public._fecha_tope() from public, anon, authenticated; grant execute on function public._fecha_tope() to authenticated;
revoke execute on function public._generar_anio(p_anio integer) from public, anon, authenticated;
revoke execute on function public._guardar_clave_historial() from public, anon, authenticated;
revoke execute on function public._horario(p_codigo text, p_fecha date, OUT ini timestamp without time zone, OUT fin timestamp without time zone) from public, anon, authenticated;
revoke execute on function public._horas(p_codigo text) from public, anon, authenticated;
revoke execute on function public._letras(t text) from public, anon, authenticated;
revoke execute on function public._limpiar_nota_dia() from public, anon, authenticated;
revoke execute on function public._mismas_horas() from public, anon, authenticated;
revoke execute on function public._personas_visibles() from public, anon, authenticated; grant execute on function public._personas_visibles() to authenticated;
revoke execute on function public._poner_codigo(p_persona uuid, p_fecha date, p_codigo text) from public, anon, authenticated;
revoke execute on function public._poner_codigo_en(p_persona uuid, p_fecha date, p_codigo text, p_departamento integer) from public, anon, authenticated;
revoke execute on function public._pueden_cambiarse(p_a uuid, p_b uuid) from public, anon, authenticated;
revoke execute on function public._puesto_anio(p_puesto text, p_anio integer) from public, anon, authenticated;
revoke execute on function public._puesto_dia(p_persona uuid, p_fecha date) from public, anon, authenticated;
revoke execute on function public._puesto_movilidad(p_persona uuid, p_fecha date) from public, anon, authenticated;
revoke execute on function public._registrar_cuadrante() from public, anon, authenticated;
revoke execute on function public._registrar_horas() from public, anon, authenticated;
revoke execute on function public._renumerar_operadores(p_departamento integer, p_turno integer) from public, anon, authenticated;
revoke execute on function public._sin_vacaciones() from public, anon, authenticated;
revoke execute on function public._solo_anios_publicados() from public, anon, authenticated;
revoke execute on function public._solo_cuentas_dadas_de_alta() from public, anon, authenticated;
revoke execute on function public._solo_mi_area() from public, anon, authenticated;
revoke execute on function public._un_dia_una_solicitud() from public, anon, authenticated;
revoke execute on function public.activar_admin(p_usuario text, p_activo boolean) from public, anon, authenticated; grant execute on function public.activar_admin(p_usuario text, p_activo boolean) to authenticated;
revoke execute on function public.admin_intercambiar(p_a uuid, p_b uuid, p_desde date, p_hasta date, p_departamento integer) from public, anon, authenticated; grant execute on function public.admin_intercambiar(p_a uuid, p_b uuid, p_desde date, p_hasta date, p_departamento integer) to authenticated;
revoke execute on function public.admin_nota_dia(p_persona uuid, p_desde date, p_hasta date, p_nota text) from public, anon, authenticated; grant execute on function public.admin_nota_dia(p_persona uuid, p_desde date, p_hasta date, p_nota text) to authenticated;
revoke execute on function public.admin_poner_codigo(p_persona uuid, p_fecha date, p_codigo text, p_departamento integer, p_motivo text) from public, anon, authenticated; grant execute on function public.admin_poner_codigo(p_persona uuid, p_fecha date, p_codigo text, p_departamento integer, p_motivo text) to authenticated;
revoke execute on function public.admin_poner_codigo_rango(p_persona uuid, p_desde date, p_hasta date, p_codigo text, p_departamento integer, p_motivo text) from public, anon, authenticated; grant execute on function public.admin_poner_codigo_rango(p_persona uuid, p_desde date, p_hasta date, p_codigo text, p_departamento integer, p_motivo text) to authenticated;
revoke execute on function public.anadir_horas(p_persona uuid, p_fecha date, p_tipo text, p_horas numeric, p_nota text) from public, anon, authenticated; grant execute on function public.anadir_horas(p_persona uuid, p_fecha date, p_tipo text, p_horas numeric, p_nota text) to authenticated;
revoke execute on function public.anio_visible() from public, anon, authenticated; grant execute on function public.anio_visible() to authenticated;
revoke execute on function public.areas_admin(p_usuario text, p_areas text[]) from public, anon, authenticated; grant execute on function public.areas_admin(p_usuario text, p_areas text[]) to authenticated;
revoke execute on function public.asegurar_anio_siguiente() from public, anon, authenticated; grant execute on function public.asegurar_anio_siguiente() to authenticated;
revoke execute on function public.asignar_hueco(p_hueco bigint, p_persona uuid) from public, anon, authenticated; grant execute on function public.asignar_hueco(p_hueco bigint, p_persona uuid) to authenticated;
revoke execute on function public.borrar_admin(p_usuario text) from public, anon, authenticated; grant execute on function public.borrar_admin(p_usuario text) to authenticated;
revoke execute on function public.borrar_horas(p_id bigint) from public, anon, authenticated; grant execute on function public.borrar_horas(p_id bigint) to authenticated;
revoke execute on function public.caducar_solicitudes() from public, anon, authenticated; grant execute on function public.caducar_solicitudes() to authenticated;
revoke execute on function public.cancelar_solicitud(p_id bigint) from public, anon, authenticated; grant execute on function public.cancelar_solicitud(p_id bigint) to authenticated;
revoke execute on function public.cerrar_hueco(p_hueco bigint) from public, anon, authenticated; grant execute on function public.cerrar_hueco(p_hueco bigint) to authenticated;
revoke execute on function public.clave_caducada() from public, anon, authenticated; grant execute on function public.clave_caducada() to authenticated;
revoke execute on function public.clave_usada_antes(p_clave text) from public, anon, authenticated; grant execute on function public.clave_usada_antes(p_clave text) to authenticated;
revoke execute on function public.codigo_patron(p_departamento integer, p_turno integer, p_fecha date) from public, anon, authenticated; grant execute on function public.codigo_patron(p_departamento integer, p_turno integer, p_fecha date) to authenticated;
revoke execute on function public.companeros_otro_rango() from public, anon, authenticated; grant execute on function public.companeros_otro_rango() to authenticated;
revoke execute on function public.correo_de_usuario(p_usuario text) from public, anon, authenticated; grant execute on function public.correo_de_usuario(p_usuario text) to anon; grant execute on function public.correo_de_usuario(p_usuario text) to authenticated;
revoke execute on function public.cubrir_con_solape(p_hueco bigint, p_m uuid, p_n uuid) from public, anon, authenticated; grant execute on function public.cubrir_con_solape(p_hueco bigint, p_m uuid, p_n uuid) to authenticated;
revoke execute on function public.dar_baja_persona(p_persona uuid, p_fecha date) from public, anon, authenticated; grant execute on function public.dar_baja_persona(p_persona uuid, p_fecha date) to authenticated;
revoke execute on function public.es_admin() from public, anon, authenticated; grant execute on function public.es_admin() to authenticated;
revoke execute on function public.extras_del_anio(p_anio integer) from public, anon, authenticated; grant execute on function public.extras_del_anio(p_anio integer) to authenticated;
revoke execute on function public.fijar_fin_formacion(p_persona uuid, p_fecha date) from public, anon, authenticated; grant execute on function public.fijar_fin_formacion(p_persona uuid, p_fecha date) to authenticated;
revoke execute on function public.generar_anio(p_anio integer) from public, anon, authenticated; grant execute on function public.generar_anio(p_anio integer) to authenticated;
revoke execute on function public.guardar_admin(p jsonb) from public, anon, authenticated; grant execute on function public.guardar_admin(p jsonb) to authenticated;
revoke execute on function public.guardar_ficha_extra(p_persona uuid, p_categoria text, p_nombre_uso text) from public, anon, authenticated; grant execute on function public.guardar_ficha_extra(p_persona uuid, p_categoria text, p_nombre_uso text) to authenticated;
revoke execute on function public.guardar_persona(p jsonb) from public, anon, authenticated; grant execute on function public.guardar_persona(p jsonb) to authenticated;
revoke execute on function public.horas_por_persona(p_anio integer) from public, anon, authenticated; grant execute on function public.horas_por_persona(p_anio integer) to authenticated;
revoke execute on function public.lista_admins() from public, anon, authenticated; grant execute on function public.lista_admins() to authenticated;
revoke execute on function public.lista_personas() from public, anon, authenticated; grant execute on function public.lista_personas() to authenticated;
revoke execute on function public.mi_cuenta() from public, anon, authenticated; grant execute on function public.mi_cuenta() to authenticated;
revoke execute on function public.mi_persona() from public, anon, authenticated; grant execute on function public.mi_persona() to authenticated;
revoke execute on function public.mis_areas() from public, anon, authenticated; grant execute on function public.mis_areas() to authenticated;
revoke execute on function public.pasar_a_titular(p_persona uuid, p_turno integer, p_desde date) from public, anon, authenticated; grant execute on function public.pasar_a_titular(p_persona uuid, p_turno integer, p_desde date) to authenticated;
revoke execute on function public.patron_cct(p_desde date, p_hasta date) from public, anon, authenticated; grant execute on function public.patron_cct(p_desde date, p_hasta date) to authenticated;
revoke execute on function public.pedir_cambio(p_companero uuid, p_fecha date, p_fecha_devolucion date, p_motivo text) from public, anon, authenticated; grant execute on function public.pedir_cambio(p_companero uuid, p_fecha date, p_fecha_devolucion date, p_motivo text) to authenticated;
revoke execute on function public.pedir_cambio_horario(p_companero uuid, p_desde date, p_hasta date, p_motivo text) from public, anon, authenticated; grant execute on function public.pedir_cambio_horario(p_companero uuid, p_desde date, p_hasta date, p_motivo text) to authenticated;
revoke execute on function public.pedir_cambio_movilidad(p_companero uuid, p_desde date, p_hasta date, p_dggvc uuid, p_motivo text) from public, anon, authenticated; grant execute on function public.pedir_cambio_movilidad(p_companero uuid, p_desde date, p_hasta date, p_dggvc uuid, p_motivo text) to authenticated;
revoke execute on function public.pedir_dia_libre(p_fecha date, p_motivo text) from public, anon, authenticated; grant execute on function public.pedir_dia_libre(p_fecha date, p_motivo text) to authenticated;
revoke execute on function public.publicar_anio(p_area text, p_anio integer, p_publicar boolean) from public, anon, authenticated; grant execute on function public.publicar_anio(p_area text, p_anio integer, p_publicar boolean) to authenticated;
revoke execute on function public.quitar_de_turno(p_persona uuid, p_fecha date, p_tipo text, p_sustituto uuid, p_motivo text, p_solape_m uuid, p_solape_n uuid) from public, anon, authenticated; grant execute on function public.quitar_de_turno(p_persona uuid, p_fecha date, p_tipo text, p_sustituto uuid, p_motivo text, p_solape_m uuid, p_solape_n uuid) to authenticated;
revoke execute on function public.quitar_mfa(p_usuario text) from public, anon, authenticated; grant execute on function public.quitar_mfa(p_usuario text) to authenticated;
revoke execute on function public.reactivar_persona(p_persona uuid) from public, anon, authenticated; grant execute on function public.reactivar_persona(p_persona uuid) to authenticated;
revoke execute on function public.resolver_solicitud(p_id bigint, p_aprueba boolean, p_movilidad jsonb) from public, anon, authenticated; grant execute on function public.resolver_solicitud(p_id bigint, p_aprueba boolean, p_movilidad jsonb) to authenticated;
revoke execute on function public.responder_solicitud(p_id bigint, p_acepta boolean, p_movilidad jsonb) from public, anon, authenticated; grant execute on function public.responder_solicitud(p_id bigint, p_acepta boolean, p_movilidad jsonb) to authenticated;
revoke execute on function public.solicitar_vacante(p_hueco bigint, p_motivo text) from public, anon, authenticated; grant execute on function public.solicitar_vacante(p_hueco bigint, p_motivo text) to authenticated;
revoke execute on function public.sugerir_usuario(p_nombre text, p_apellido1 text, p_apellido2 text, p_persona uuid) from public, anon, authenticated; grant execute on function public.sugerir_usuario(p_nombre text, p_apellido1 text, p_apellido2 text, p_persona uuid) to authenticated;

alter default privileges in schema public revoke execute on functions from anon, public;
alter default privileges for role postgres in schema public revoke execute on functions from anon, public;

-- =====================================================================
-- 13. CONFIGURACIÓN INICIAL (no son datos de personas)
-- Departamentos y su área, códigos de turno con sus horas y colores, el ciclo de cada turno (para generar los años
-- siguientes), los puestos de Vigilantes, las bases de los Agentes y los festivos de Madrid capital.
-- =====================================================================
insert into public.codigos_turno select * from json_populate_recordset(null::public.codigos_turno, '[{"codigo":"F","nombre":"Formación","hora_inicio":null,"hora_fin":null,"horas":8,"color":"#d63c8e"}, 
 {"codigo":"F12","nombre":"Formación 12 h","hora_inicio":"07:00:00","hora_fin":"19:00:00","horas":12,"color":"#d63c8e"}, 
 {"codigo":"L","nombre":"Libre","hora_inicio":null,"hora_fin":null,"horas":0,"color":"#e4e9ec"}, 
 {"codigo":"M","nombre":"Mañana","hora_inicio":"07:00:00","hora_fin":"15:00:00","horas":8,"color":"#4ba3e0"}, 
 {"codigo":"MT","nombre":"Mañana-Tarde","hora_inicio":"07:00:00","hora_fin":"19:00:00","horas":12,"color":"#1e4fd6"}, 
 {"codigo":"N","nombre":"Noche","hora_inicio":"23:00:00","hora_fin":"07:00:00","horas":8,"color":"#4a5966"}, 
 {"codigo":"S","nombre":"Solape","hora_inicio":null,"hora_fin":null,"horas":8,"color":"#c94b3c"}, 
 {"codigo":"T","nombre":"Tarde","hora_inicio":"15:00:00","hora_fin":"23:00:00","horas":8,"color":"#f0932b"}, 
 {"codigo":"TN","nombre":"Tarde-Noche","hora_inicio":"19:00:00","hora_fin":"07:00:00","horas":12,"color":"#5c6b78"}, 
 {"codigo":"V","nombre":"Vacaciones","hora_inicio":null,"hora_fin":null,"horas":0,"color":"#2a9d6e"}]');
insert into public.departamentos select * from json_populate_recordset(null::public.departamentos, '[{"id":1,"nombre":"Jefatura de Turno","slug":"jt","area":"centro_control","grupo":null}, 
 {"id":2,"nombre":"Supervisores","slug":"sv","area":"centro_control","grupo":null}, 
 {"id":3,"nombre":"Centro de Control","slug":"cct","area":"centro_control","grupo":null}, 
 {"id":5,"nombre":"Vigilantes","slug":"vig","area":"incidencias","grupo":null}, 
 {"id":6,"nombre":"Coordinadores","slug":"coord","area":"incidencias","grupo":"aiam"}, 
 {"id":7,"nombre":"Jefes de equipo","slug":"je","area":"incidencias","grupo":"aiam"}, 
 {"id":8,"nombre":"Agentes","slug":"aiam","area":"incidencias","grupo":"aiam"}]');
insert into public.festivos select * from json_populate_recordset(null::public.festivos, '[{"fecha":"2026-01-01","nombre":"Año Nuevo"}, 
 {"fecha":"2026-01-06","nombre":"Epifanía del Señor"}, 
 {"fecha":"2026-04-02","nombre":"Jueves Santo"}, 
 {"fecha":"2026-04-03","nombre":"Viernes Santo"}, 
 {"fecha":"2026-05-01","nombre":"Fiesta del Trabajo"}, 
 {"fecha":"2026-05-02","nombre":"Fiesta de la Comunidad de Madrid"}, 
 {"fecha":"2026-05-15","nombre":"San Isidro (local)"}, 
 {"fecha":"2026-08-15","nombre":"Asunción de la Virgen"}, 
 {"fecha":"2026-10-12","nombre":"Fiesta Nacional"}, 
 {"fecha":"2026-11-02","nombre":"Todos los Santos (traslado)"}, 
 {"fecha":"2026-11-09","nombre":"Almudena (local)"}, 
 {"fecha":"2026-12-07","nombre":"Constitución (traslado)"}, 
 {"fecha":"2026-12-08","nombre":"Inmaculada Concepción"}, 
 {"fecha":"2026-12-25","nombre":"Natividad del Señor"}, 
 {"fecha":"2027-01-01","nombre":"Año Nuevo"}, 
 {"fecha":"2027-01-06","nombre":"Epifanía del Señor"}, 
 {"fecha":"2027-03-19","nombre":"San José"}, 
 {"fecha":"2027-03-25","nombre":"Jueves Santo"}, 
 {"fecha":"2027-03-26","nombre":"Viernes Santo"}, 
 {"fecha":"2027-05-01","nombre":"Fiesta del Trabajo"}, 
 {"fecha":"2027-05-15","nombre":"San Isidro (local)"}, 
 {"fecha":"2027-08-16","nombre":"Asunción de la Virgen (traslado)"}, 
 {"fecha":"2027-10-12","nombre":"Fiesta Nacional"}, 
 {"fecha":"2027-11-01","nombre":"Todos los Santos"}, 
 {"fecha":"2027-11-09","nombre":"Almudena (local)"}, 
 {"fecha":"2027-12-06","nombre":"Constitución"}, 
 {"fecha":"2027-12-08","nombre":"Inmaculada Concepción"}, 
 {"fecha":"2027-12-25","nombre":"Natividad del Señor"}]');
insert into public.patrones select * from json_populate_recordset(null::public.patrones, '[{"departamento_id":1,"turno_numero":1,"ciclo":35,"fecha_base":"2026-11-27","secuencia":["L","L","L","T","T","T","T","TN","TN","TN","L","L","L","L","L","L","L","N","N","N","N","L","L","L","M","M","M","M","MT","MT","MT","L","L","L","L"],"actualizado_en":"2026-09-28T12:01:55.793896+00:00"}, 
 {"departamento_id":1,"turno_numero":2,"ciclo":35,"fecha_base":"2026-11-27","secuencia":["L","L","L","N","N","N","N","L","L","L","M","M","M","M","MT","MT","MT","L","L","L","L","L","L","L","T","T","T","T","TN","TN","TN","L","L","L","L"],"actualizado_en":"2026-09-28T12:01:55.793896+00:00"}, 
 {"departamento_id":1,"turno_numero":3,"ciclo":35,"fecha_base":"2026-11-27","secuencia":["MT","MT","MT","L","L","L","L","L","L","L","T","T","T","T","TN","TN","TN","L","L","L","L","L","L","L","N","N","N","N","L","L","L","M","M","M","M"],"actualizado_en":"2026-09-28T12:01:55.793896+00:00"}, 
 {"departamento_id":1,"turno_numero":4,"ciclo":35,"fecha_base":"2026-11-27","secuencia":["TN","TN","TN","L","L","L","L","L","L","L","N","N","N","N","L","L","L","M","M","M","M","MT","MT","MT","L","L","L","L","L","L","L","T","T","T","T"],"actualizado_en":"2026-09-28T12:01:55.793896+00:00"}, 
 {"departamento_id":1,"turno_numero":5,"ciclo":35,"fecha_base":"2026-11-27","secuencia":["L","L","L","M","M","M","M","MT","MT","MT","L","L","L","L","L","L","L","T","T","T","T","TN","TN","TN","L","L","L","L","L","L","L","N","N","N","N"],"actualizado_en":"2026-09-28T12:01:55.793896+00:00"}, 
 {"departamento_id":2,"turno_numero":1,"ciclo":35,"fecha_base":"2026-11-27","secuencia":["L","L","L","M","M","M","N","N","TN","TN","L","L","L","L","L","L","L","T","T","T","T","T","L","L","L","L","L","M","M","MT","MT","N","N","N","L"],"actualizado_en":"2026-09-28T12:01:55.793896+00:00"}, 
 {"departamento_id":2,"turno_numero":2,"ciclo":35,"fecha_base":"2026-11-27","secuencia":["L","L","L","T","T","T","T","T","L","L","L","L","L","M","M","MT","MT","N","N","N","L","L","L","L","M","M","M","N","N","TN","TN","L","L","L","L"],"actualizado_en":"2026-09-28T12:01:55.793896+00:00"}, 
 {"departamento_id":2,"turno_numero":3,"ciclo":35,"fecha_base":"2026-11-27","secuencia":["M","MT","MT","N","N","N","L","L","L","L","M","M","M","N","N","TN","TN","L","L","L","L","L","L","L","T","T","T","T","T","L","L","L","L","L","M"],"actualizado_en":"2026-09-28T12:01:55.793896+00:00"}, 
 {"departamento_id":2,"turno_numero":4,"ciclo":35,"fecha_base":"2026-11-27","secuencia":["T","L","L","L","L","L","M","M","MT","MT","N","N","N","L","L","L","L","M","M","M","N","N","TN","TN","L","L","L","L","L","L","L","T","T","T","T"],"actualizado_en":"2026-09-28T12:01:55.793896+00:00"}, 
 {"departamento_id":2,"turno_numero":5,"ciclo":35,"fecha_base":"2026-11-27","secuencia":["N","TN","TN","L","L","L","L","L","L","L","T","T","T","T","T","L","L","L","L","L","M","M","MT","MT","N","N","N","L","L","L","L","M","M","M","N"],"actualizado_en":"2026-09-28T12:01:55.793896+00:00"}, 
 {"departamento_id":3,"turno_numero":1,"ciclo":56,"fecha_base":"2026-11-06","secuencia":["N","TN","TN","L","L","L","L","L","L","L","N","N","N","N","N","TN","TN","L","L","L","L","L","L","L","N","N","N","N","N","TN","TN","L","L","L","L","L","L","L","N","N","N","N","N","TN","TN","L","L","L","L","L","L","L","N","N","N","N"],"actualizado_en":"2026-09-28T12:01:55.793896+00:00"}, 
 {"departamento_id":3,"turno_numero":2,"ciclo":56,"fecha_base":"2026-11-06","secuencia":["M","L","L","L","L","L","L","L","MT","MT","T","T","T","T","T","L","L","N","N","N","N","N","TN","TN","L","L","L","L","L","L","L","M","M","M","M","M","L","L","L","L","L","L","L","MT","MT","T","T","T","T","T","L","L","M","M","M","M"],"actualizado_en":"2026-09-28T12:01:55.793896+00:00"}, 
 {"departamento_id":3,"turno_numero":3,"ciclo":56,"fecha_base":"2026-11-06","secuencia":["L","L","L","M","M","M","M","M","L","L","L","L","L","L","L","MT","MT","T","T","T","T","T","L","L","M","M","M","M","M","L","L","L","L","L","L","L","MT","MT","T","T","T","T","T","L","L","N","N","N","N","N","TN","TN","L","L","L","L"],"actualizado_en":"2026-09-28T12:01:55.793896+00:00"}, 
 {"departamento_id":3,"turno_numero":4,"ciclo":56,"fecha_base":"2026-11-06","secuencia":["L","MT","MT","T","T","T","T","T","L","L","M","M","M","M","M","L","L","L","L","L","L","L","MT","MT","T","T","T","T","T","L","L","N","N","N","N","N","TN","TN","L","L","L","L","L","L","L","M","M","M","M","M","L","L","L","L","L","L"],"actualizado_en":"2026-09-28T12:01:55.793896+00:00"}, 
 {"departamento_id":3,"turno_numero":5,"ciclo":56,"fecha_base":"2026-11-06","secuencia":["T","L","L","N","N","N","N","N","TN","TN","L","L","L","L","L","L","L","M","M","M","M","M","L","L","L","L","L","L","L","MT","MT","T","T","T","T","T","L","L","M","M","M","M","M","L","L","L","L","L","L","L","MT","MT","T","T","T","T"],"actualizado_en":"2026-09-28T12:01:55.793896+00:00"}, 
 {"departamento_id":5,"turno_numero":1,"ciclo":35,"fecha_base":"2024-01-01","secuencia":["T","T","T","T","T","L","L","L","L","L","L","L","MT","MT","M","M","M","M","M","L","L","N","N","N","N","N","TN","TN","L","L","L","L","L","L","L"],"actualizado_en":"2026-10-24T23:41:42.680369+00:00"}, 
 {"departamento_id":5,"turno_numero":2,"ciclo":35,"fecha_base":"2024-01-01","secuencia":["M","M","M","M","M","L","L","N","N","N","N","N","TN","TN","L","L","L","L","L","L","L","T","T","T","T","T","L","L","L","L","L","L","L","MT","MT"],"actualizado_en":"2026-10-24T23:41:42.680369+00:00"}, 
 {"departamento_id":5,"turno_numero":3,"ciclo":35,"fecha_base":"2024-01-01","secuencia":["L","L","L","L","L","MT","MT","M","M","M","M","M","L","L","N","N","N","N","N","TN","TN","L","L","L","L","L","L","L","T","T","T","T","T","L","L"],"actualizado_en":"2026-10-24T23:41:42.680369+00:00"}, 
 {"departamento_id":5,"turno_numero":4,"ciclo":35,"fecha_base":"2024-01-01","secuencia":["N","N","N","N","N","TN","TN","L","L","L","L","L","L","L","T","T","T","T","T","L","L","L","L","L","L","L","MT","MT","M","M","M","M","M","L","L"],"actualizado_en":"2026-10-24T23:41:42.680369+00:00"}, 
 {"departamento_id":5,"turno_numero":5,"ciclo":35,"fecha_base":"2024-01-01","secuencia":["L","L","L","L","L","L","L","T","T","T","T","T","L","L","L","L","L","L","L","MT","MT","M","M","M","M","M","L","L","N","N","N","N","N","TN","TN"],"actualizado_en":"2026-10-24T23:41:42.680369+00:00"}, 
 {"departamento_id":5,"turno_numero":6,"ciclo":7,"fecha_base":"2024-01-01","secuencia":["M","M","M","M","M","L","L"],"actualizado_en":"2026-10-24T23:41:42.680369+00:00"}, 
 {"departamento_id":5,"turno_numero":7,"ciclo":7,"fecha_base":"2024-01-01","secuencia":["T","T","T","T","T","L","L"],"actualizado_en":"2026-10-24T23:41:42.680369+00:00"}, 
 {"departamento_id":6,"turno_numero":1,"ciclo":5,"fecha_base":"2026-02-04","secuencia":["L","L","MT","TN","L"],"actualizado_en":"2026-11-05T02:30:33.024993+00:00"}, 
 {"departamento_id":7,"turno_numero":1,"ciclo":5,"fecha_base":"2026-02-04","secuencia":["L","L","MT","TN","L"],"actualizado_en":"2026-11-05T02:30:33.024993+00:00"}, 
 {"departamento_id":8,"turno_numero":1,"ciclo":5,"fecha_base":"2026-02-04","secuencia":["L","L","MT","TN","L"],"actualizado_en":"2026-11-05T02:30:33.024993+00:00"}, 
 {"departamento_id":6,"turno_numero":2,"ciclo":5,"fecha_base":"2026-02-04","secuencia":["L","L","L","MT","TN"],"actualizado_en":"2026-11-05T02:30:33.024993+00:00"}, 
 {"departamento_id":7,"turno_numero":2,"ciclo":5,"fecha_base":"2026-02-04","secuencia":["L","L","L","MT","TN"],"actualizado_en":"2026-11-05T02:30:33.024993+00:00"}, 
 {"departamento_id":8,"turno_numero":2,"ciclo":5,"fecha_base":"2026-02-04","secuencia":["L","L","L","MT","TN"],"actualizado_en":"2026-11-05T02:30:33.024993+00:00"}, 
 {"departamento_id":6,"turno_numero":3,"ciclo":5,"fecha_base":"2026-02-04","secuencia":["TN","L","L","L","MT"],"actualizado_en":"2026-11-05T02:30:33.024993+00:00"}, 
 {"departamento_id":7,"turno_numero":3,"ciclo":5,"fecha_base":"2026-02-04","secuencia":["TN","L","L","L","MT"],"actualizado_en":"2026-11-05T02:30:33.024993+00:00"}, 
 {"departamento_id":8,"turno_numero":3,"ciclo":5,"fecha_base":"2026-02-04","secuencia":["TN","L","L","L","MT"],"actualizado_en":"2026-11-05T02:30:33.024993+00:00"}, 
 {"departamento_id":6,"turno_numero":4,"ciclo":5,"fecha_base":"2026-02-04","secuencia":["MT","TN","L","L","L"],"actualizado_en":"2026-11-05T02:30:33.024993+00:00"}, 
 {"departamento_id":7,"turno_numero":4,"ciclo":5,"fecha_base":"2026-02-04","secuencia":["MT","TN","L","L","L"],"actualizado_en":"2026-11-05T02:30:33.024993+00:00"}, 
 {"departamento_id":8,"turno_numero":4,"ciclo":5,"fecha_base":"2026-02-04","secuencia":["MT","TN","L","L","L"],"actualizado_en":"2026-11-05T02:30:33.024993+00:00"}, 
 {"departamento_id":6,"turno_numero":5,"ciclo":5,"fecha_base":"2026-02-04","secuencia":["L","MT","TN","L","L"],"actualizado_en":"2026-11-05T02:30:33.024993+00:00"}, 
 {"departamento_id":7,"turno_numero":5,"ciclo":5,"fecha_base":"2026-02-04","secuencia":["L","MT","TN","L","L"],"actualizado_en":"2026-11-05T02:30:33.024993+00:00"}, 
 {"departamento_id":8,"turno_numero":5,"ciclo":5,"fecha_base":"2026-02-04","secuencia":["L","MT","TN","L","L"],"actualizado_en":"2026-11-05T02:30:33.024993+00:00"}]');
insert into public.puestos select * from json_populate_recordset(null::public.puestos, '[{"codigo":"V-1","departamento_id":5,"nombre":"Furgón","desfase_horas":-1,"orden":1,"se_cubre":true}, 
 {"codigo":"V-2","departamento_id":5,"nombre":"Furgón","desfase_horas":0,"orden":2,"se_cubre":true}, 
 {"codigo":"V-3","departamento_id":5,"nombre":"Furgón","desfase_horas":-1,"orden":3,"se_cubre":true}, 
 {"codigo":"V-4","departamento_id":5,"nombre":"Furgón","desfase_horas":0,"orden":4,"se_cubre":true}, 
 {"codigo":"M-1","departamento_id":5,"nombre":"Moto mañana","desfase_horas":0,"orden":5,"se_cubre":true}, 
 {"codigo":"M-4","departamento_id":5,"nombre":"Moto mañana (2ª)","desfase_horas":0,"orden":6,"se_cubre":false}, 
 {"codigo":"M-3","departamento_id":5,"nombre":"Moto tarde","desfase_horas":-1,"orden":7,"se_cubre":true}, 
 {"codigo":"M-2","departamento_id":5,"nombre":"Moto tarde (2ª)","desfase_horas":-1,"orden":8,"se_cubre":false}, 
 {"codigo":"CO-MA","departamento_id":6,"nombre":"Méndez Álvaro","desfase_horas":0,"orden":101,"se_cubre":true}, 
 {"codigo":"J-MA","departamento_id":7,"nombre":"Méndez Álvaro","desfase_horas":0,"orden":101,"se_cubre":true}, 
 {"codigo":"A-MA","departamento_id":8,"nombre":"Méndez Álvaro","desfase_horas":0,"orden":101,"se_cubre":true}, 
 {"codigo":"J-VA","departamento_id":7,"nombre":"Valencia","desfase_horas":0,"orden":102,"se_cubre":true}, 
 {"codigo":"A-VA","departamento_id":8,"nombre":"Valencia","desfase_horas":0,"orden":102,"se_cubre":true}, 
 {"codigo":"J-CA","departamento_id":7,"nombre":"Calderón","desfase_horas":0,"orden":103,"se_cubre":true}, 
 {"codigo":"A-CA","departamento_id":8,"nombre":"Calderón","desfase_horas":0,"orden":103,"se_cubre":true}, 
 {"codigo":"J-MO","departamento_id":7,"nombre":"Moreras","desfase_horas":0,"orden":104,"se_cubre":true}, 
 {"codigo":"A-MO","departamento_id":8,"nombre":"Moreras","desfase_horas":0,"orden":104,"se_cubre":true}, 
 {"codigo":"J-BA","departamento_id":7,"nombre":"Badajoz","desfase_horas":0,"orden":105,"se_cubre":true}, 
 {"codigo":"A-BA","departamento_id":8,"nombre":"Badajoz","desfase_horas":0,"orden":105,"se_cubre":true}]');

select setval('public.departamentos_id_seq', (select max(id) from public.departamentos));

-- =====================================================================
-- COMPROBACIÓN FINAL
-- Debe salir SOLO correo_de_usuario.
-- =====================================================================
select p.proname as funcion_abierta_sin_sesion
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute')
order by 1;
