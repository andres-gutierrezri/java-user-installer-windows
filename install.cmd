@echo off
rem ===========================================================================
rem  install.cmd - Lanzador para CMD
rem  1) Habilita scripts de PowerShell para el usuario actual (sin administrador)
rem  2) Instala JDK + JRE, variables JAVA_HOME / JRE_HOME, PATH y acceso directo
rem  Uso:  install.cmd [-Version latest|lts|NN] [-InstallRoot C:\Programs] [-SkipJre] [-NoShortcut] [-Force]
rem  Autor: Ingeniero Andres Felipe Gutierrez Rivera - Licencia MIT
rem ===========================================================================
setlocal
set "RAIZ=%~dp0"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

echo.
echo [1/2] Habilitando la ejecucion de scripts (ambito CurrentUser)...
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%RAIZ%src\Enable-PowerShellScripts.ps1"
if errorlevel 1 goto :error

echo.
echo [2/2] Instalando Java...
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%RAIZ%src\Install-Java.ps1" %*
if errorlevel 1 goto :error

echo.
echo Proceso finalizado correctamente. Abra una NUEVA ventana de CMD y ejecute: java -version
exit /b 0

:error
echo.
echo [ERROR] El proceso termino con errores. Revise los mensajes anteriores.
exit /b 1
