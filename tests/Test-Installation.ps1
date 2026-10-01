<#
.SYNOPSIS
    Pruebas de aceptación posteriores a la instalación (ejecutar en una consola NUEVA).
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Installation.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\src\JavaUserEnv.psm1') -Force

$script:fallos = 0
function Test-Condicion {
    param([string]$Nombre, [scriptblock]$Prueba)
    try {
        if (& $Prueba) { Write-Host "[OK]    $Nombre" -ForegroundColor Green }
        else { Write-Host "[FALLO] $Nombre" -ForegroundColor Red; $script:fallos++ }
    }
    catch { Write-Host "[FALLO] $Nombre ($($_.Exception.Message))" -ForegroundColor Red; $script:fallos++ }
}

$javaHome = Get-UserEnvironmentValue -Name 'JAVA_HOME'
$jreHome  = Get-UserEnvironmentValue -Name 'JRE_HOME'
$pathRaw  = [string](Get-UserEnvironmentValue -Name 'Path')

Test-Condicion 'Política de ejecución CurrentUser permite scripts' { (Get-ExecutionPolicy -Scope CurrentUser) -in 'RemoteSigned', 'Unrestricted', 'Bypass' }
Test-Condicion 'JAVA_HOME definido en HKCU'                         { -not [string]::IsNullOrWhiteSpace($javaHome) }
Test-Condicion 'JAVA_HOME apunta a un JDK (javac.exe existe)'       { Test-Path -LiteralPath (Join-Path $javaHome 'bin\javac.exe') }
Test-Condicion 'JRE_HOME definido y con java.exe'                   { $jreHome -and (Test-Path -LiteralPath (Join-Path $jreHome 'bin\java.exe')) }
Test-Condicion 'PATH de usuario contiene %JAVA_HOME%\bin'           { $pathRaw -match [regex]::Escape('%JAVA_HOME%\bin') }
Test-Condicion 'PATH de usuario contiene %JRE_HOME%\bin'            { $pathRaw -match [regex]::Escape('%JRE_HOME%\bin') }
Test-Condicion 'No se requirieron privilegios de administrador'     { -not (Test-IsAdministrator) }
Test-Condicion 'Acceso directo en el escritorio'                    { Test-Path -LiteralPath (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Configuración de Java.lnk') }
Test-Condicion 'java -version responde desde una consola nueva'     { (& cmd.exe /c 'java -version 2>&1') -match 'version' }
Test-Condicion 'javac -version responde desde una consola nueva'    { (& cmd.exe /c 'javac -version 2>&1') -match 'javac' }

if ($script:fallos -gt 0) { Write-Host "`n$($script:fallos) verificación(es) fallida(s)." -ForegroundColor Red; exit 1 }
Write-Host "`nInstalación verificada correctamente." -ForegroundColor Green
exit 0
