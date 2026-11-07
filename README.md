# App Cuadrante

Aplicación interna de cuadrantes y cambios de turno de Explotación (Centro de Control y Atención de incidencias).
Web instalable en el móvil (PWA), publicada en **https://appcuadrante.es**, con la base de datos en Supabase
(región eu-central-1, Frankfurt, Unión Europea).

Este repositorio contiene el código, las herramientas y la estructura de la base de datos.
**No contiene datos de personas.**

## Contenido

| Ruta | Qué es |
| --- | --- |
| `app-cuadrante-conectado.html` | La app: HTML, CSS y JavaScript en un solo archivo (versión legible, comentada) |
| `publicar/` | Lo que se sirve en appcuadrante.es: la app comprimida, el manifest y los iconos. `despertador.yml` es la tarea diaria de GitHub Actions del repositorio público |
| `supabase/instalacion.sql` | Estructura completa de la base de datos: tablas, funciones, automatismos, reglas de acceso (RLS) y configuración de turnos, puestos, bases y festivos |
| `supabase/consulta_estructura.sql` | Consulta de solo lectura que exporta la estructura real de producción (para regenerar `instalacion.sql`) |
| `supabase/plantillas_correo.md` | Textos de los correos de activación de cuenta y de nueva contraseña |
| `herramientas/` | Servidor local de pruebas, herramienta de publicar, copia de seguridad, generador de `instalacion.sql` e iconos |
| `Probar_App.bat` · `Publicar_App.bat` · `Copia_Seguridad.bat` | Accesos directos a esas herramientas (Windows) |

## Cómo se trabaja

- **Probar en local:** `Probar_App.bat` abre la app en http://localhost:8765/ (con el archivo abierto directamente, el navegador bloquea la conexión con Supabase).
- **Publicar una versión:** `Publicar_App.bat` → «Generar» → se crea `publicar/index.html` comprimido → se sube al repositorio público `appcuadrante.github.io`. Los usuarios ven el aviso «Hay una versión nueva».
- **Cambios en la base de datos:** un archivo SQL en `supabase/cambios/NN_nombre.sql`, ejecutado en el editor SQL de Supabase. Al cerrar una etapa se regenera `instalacion.sql` con `consulta_estructura.sql` y `herramientas/generar_instalacion.ps1`.

## Datos y copias

- Los datos viven solo en Supabase. La seguridad la aplica la base de datos: sin sesión no se ve nada.
- Copia de los datos: desde la app, Gestión → «Copia de los datos» (un archivo .json con todas las tablas). Las copias contienen datos personales: se guardan solo en un almacenamiento autorizado por la empresa, nunca en este repositorio.
- Reinstalación completa: `supabase/instalacion.sql` en un proyecto de Supabase vacío + la copia de los datos.

## Autor

Luis Vásquez. Desarrollado con Claude Code (asistente de programación de Anthropic) como herramienta de desarrollo.
Documentación: «App Cuadrante · Seguridad y funcionamiento».
