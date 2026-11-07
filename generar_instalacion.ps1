param([string[]]$csv, [string]$salida)   # uno o varios CSV de consulta_estructura.sql
$rows = Import-Csv ($csv -split ',') -Encoding UTF8   # (desde un .bat llegan separados por comas)
$sb = New-Object System.Text.StringBuilder
function L([string]$t){ [void]$sb.AppendLine($t) }
function Seccion([string]$titulo, [string]$texto){
  L ""; L "-- ====================================================================="
  L ("-- " + $titulo)
  if($texto){ $texto -split "`n" | ForEach-Object { L ("-- " + $_) } }
  L "-- ====================================================================="
}
function Ddl($orden){ $rows | Where-Object { $_.orden -eq $orden } | Sort-Object nombre | ForEach-Object { L $_.ddl } }

L "-- ====================================================================="
L "-- App Cuadrante · INSTALACIÓN COMPLETA DE LA BASE DE DATOS"
L ("-- Generado el " + (Get-Date -Format "dd/MM/yyyy") + " a partir de la base de datos en producción (estado real, no un historial de cambios).")
L "--"
L "-- Para qué sirve: crear desde cero, en un proyecto de Supabase VACÍO, toda la estructura que usa la app (tablas,"
L "-- reglas de seguridad, funciones, automatismos y la configuración de turnos). NO contiene datos de personas."
L "-- El traspaso normal de la app NO necesita este archivo (el proyecto de Supabase se transfiere entero, con sus datos);"
L "-- sirve como documentación técnica completa y para reinstalar la base de datos si alguna vez hiciera falta."
L "--"
L "-- Uso: Supabase → SQL Editor → New query → pegar entero → Run (en un proyecto nuevo y vacío)."
L "-- Después: (1) guardar la clave de Brevo en Vault con el nombre brevo_api_key; (2) crear la cuenta del administrador"
L "-- inicial (ver la guía técnica); (3) dar de alta al personal desde la app."
L "-- ====================================================================="
L ""
L "set check_function_bodies = off;  -- las funciones se crean en orden alfabético; se comprueban al usarse"

Seccion "1. EXTENSIONES" "pg_net: envío de los avisos por correo · supabase_vault: guarda la clave del correo · pgcrypto / uuid-ossp: identificadores."
$rows | Where-Object { $_.orden -eq '1' } | Sort-Object nombre | ForEach-Object {
  if($_.nombre -eq 'supabase_vault'){ L "create extension if not exists supabase_vault;" }
  else { L ("create extension if not exists " + ($(if($_.nombre -match '-'){ '"' + $_.nombre + '"' } else { $_.nombre })) + " with schema extensions;") }
}

Seccion "2. TIPOS" "Estados de una solicitud de cambio."
Ddl '2'

Seccion "3. SECUENCIAS (numeración automática de los identificadores)" ""
Ddl '3'

Seccion "4. TABLAS" ("departamentos · codigos_turno · patrones (ciclo de cada turno) · personas · fichas (datos privados) · cuentas (acceso)`n" +
  "cuadrante_dia (un registro por persona y día) · solicitudes_cambio · huecos (vacantes/solapes) · horas_extra`n" +
  "movilidad_cambios (puesto DGGVC) · habilitaciones (dónde más puede cubrir) · registro_cuadrante (historial)`n" +
  "puestos (Vigilantes: V-1…V-4 y motos, con su horario · Agentes: la base) · festivos (de Madrid capital, para las motos)`n" +
  "anios_publicados (años siguientes que la plantilla de cada área ya puede ver) · historial_claves (huellas de las 15 últimas`n" +
  "contraseñas de cada cuenta; nadie puede leerla desde fuera)")
Ddl '4'
L ""
$rows | Where-Object { $_.orden -eq '4' -and $_.ddl -match "nextval\('([a-z_]+)'" } | ForEach-Object {
  $seq = [regex]::Match($_.ddl, "nextval\('([a-z_]+)'").Groups[1].Value
  L ("alter sequence public." + $seq + " owned by public." + $_.nombre + ".id;")
}

Seccion "5. CLAVES PRIMARIAS Y VALORES ÚNICOS" ""
Ddl '5'
Seccion "6. RELACIONES ENTRE TABLAS Y COMPROBACIONES" ""
Ddl '6'
Seccion "7. ÍNDICES (búsquedas rápidas)" ""
Ddl '7'

Seccion "8. FUNCIONES" ("Toda la lógica de negocio está en la base de datos: la app nunca escribe directamente en el cuadrante.`n" +
  "Las que empiezan por _ son internas (solo las usan otras funciones); el resto las llama la app con sesión iniciada.")
$rows | Where-Object { $_.orden -eq '8' } | Sort-Object nombre | ForEach-Object { L ""; L $_.ddl }

Seccion "9. AUTOMATISMOS (triggers)" ("Registro de cambios, avisos por correo, reglas de las solicitudes (un día una solicitud, mismas horas, sin vacaciones),`n" +
  "nombre corto de cada persona y el guardián de áreas (solo_mi_area: un administrador solo puede cambiar lo de sus áreas).")
Ddl '9'
L ""
L "-- Automatismos sobre las cuentas de acceso (están en el esquema auth: se añaden aparte)"
L "-- · Solo puede activar su acceso quien tenga una cuenta dada de alta en la app"
L "drop trigger if exists solo_cuentas_dadas_de_alta on auth.users;"
L "create trigger solo_cuentas_dadas_de_alta before insert on auth.users for each row execute function public._solo_cuentas_dadas_de_alta();"
L "-- · Historial de contraseñas (las 15 últimas, para no repetirlas) y fecha del último cambio (caducidad a los 90 días)"
L "drop trigger if exists guardar_clave_historial on auth.users;"
L "create trigger guardar_clave_historial after insert or update of encrypted_password on auth.users for each row execute function public._guardar_clave_historial();"

Seccion "10. SEGURIDAD POR FILAS (RLS)" "Sin sesión no se ve nada. Con sesión, cada regla de abajo dice quién puede ver o cambiar qué."
Ddl '10'
Seccion "11. REGLAS DE ACCESO (políticas)" ""
Ddl '11'

Seccion "12. QUIÉN PUEDE LLAMAR A CADA FUNCIÓN" ("Sin sesión (anon) solo correo_de_usuario (la pantalla de acceso). Las internas (_) no se pueden llamar desde fuera.`n" +
  "Supabase da permiso a 'anon' en cada función nueva: por eso se cierran todas aquí y se cambia el valor por defecto.")
Ddl '12'
L ""
L "alter default privileges in schema public revoke execute on functions from anon, public;"
L "alter default privileges for role postgres in schema public revoke execute on functions from anon, public;"

Seccion "13. CONFIGURACIÓN INICIAL (no son datos de personas)" ("Departamentos y su área, códigos de turno con sus horas y colores, el ciclo de cada turno (para generar los años`n" +
  "siguientes), los puestos de Vigilantes, las bases de los Agentes y los festivos de Madrid capital.")
Ddl '13'
L ""
L "select setval('public.departamentos_id_seq', (select max(id) from public.departamentos));"

Seccion "COMPROBACIÓN FINAL" "Debe salir SOLO correo_de_usuario."
L "select p.proname as funcion_abierta_sin_sesion"
L "from pg_proc p join pg_namespace n on n.oid = p.pronamespace"
L "where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute')"
L "order by 1;"

[IO.File]::WriteAllText($salida, $sb.ToString(), (New-Object Text.UTF8Encoding($false)))
"Escrito: " + $salida + " (" + [math]::Round((Get-Item $salida).Length / 1KB) + " KB)"
