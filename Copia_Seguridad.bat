@echo off
rem Copia de seguridad de todo el proyecto App Cuadrante (en el Google Drive del proyecto: Mi unidad\Copias AppCuadrante)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0herramientas\copia_seguridad.ps1"
pause
