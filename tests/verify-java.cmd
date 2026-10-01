@echo off
rem ===========================================================================
rem  verify-java.cmd - Verificacion desde CMD puro (ejecutar en una ventana NUEVA)
rem ===========================================================================
setlocal
set FALLOS=0

echo --- Variables ---
echo JAVA_HOME = %JAVA_HOME%
echo JRE_HOME  = %JRE_HOME%
if "%JAVA_HOME%"=="" set /a FALLOS+=1

echo.
echo --- java -version ---
java -version
if errorlevel 1 set /a FALLOS+=1

echo.
echo --- javac -version ---
javac -version
if errorlevel 1 set /a FALLOS+=1

echo.
echo --- Binarios resueltos en PATH ---
where java
where javac

echo.
if %FALLOS% GTR 0 (
  echo RESULTADO: %FALLOS% verificacion(es) fallida(s). Abra una ventana nueva e intente de nuevo.
  exit /b 1
)
echo RESULTADO: todas las verificaciones fueron exitosas.
exit /b 0
