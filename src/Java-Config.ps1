<#
.SYNOPSIS
    Panel interactivo de configuración de Java para el usuario actual.

.DESCRIPTION
    Es el destino del acceso directo "Configuración de Java" del escritorio.
    Permite consultar el estado, verificar versiones, cambiar el JDK/JRE activo
    (JAVA_HOME / JRE_HOME), abrir el editor de variables de entorno de Windows y
    abrir la carpeta de instalación.

    Aclaración: Java Control Panel (javacpl) pertenece al JRE 8 de Oracle y no se incluye
    en las distribuciones Temurin ni en Java 9+. Este panel cumple una función equivalente
    para la gestión de versiones y del entorno.

.NOTES
    Autor   : Ingeniero Andrés Felipe Gutiérrez Rivera
    Licencia: MIT
#>

#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'JavaUserEnv.psm1') -Force

# Este script reside en <JavaRoot>\tools\ ; las versiones están en <JavaRoot>\jdk-* y jre-*
$JavaRoot = Split-Path -Parent $PSScriptRoot

function Invoke-JavaTool {
    param([string]$Home_, [string]$Tool)

    $exe = Join-Path $Home_ "bin\$Tool.exe"
    if (-not (Test-Path -LiteralPath $exe)) { Write-Host "  ($Tool no disponible en $Home_)" -ForegroundColor DarkYellow; return }
    $previo = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'   # java -version escribe en stderr
    & $exe -version 2>&1 | ForEach-Object { "  $_" }
    $ErrorActionPreference = $previo
}

function Show-Status {
    Write-Host "`nEstado del entorno Java (usuario: $env:USERNAME)" -ForegroundColor Cyan
    Write-Host "  Carpeta de instalación : $JavaRoot"
    Write-Host "  JAVA_HOME              : $(Get-UserEnvironmentValue -Name 'JAVA_HOME')"
    Write-Host "  JRE_HOME               : $(Get-UserEnvironmentValue -Name 'JRE_HOME')"
    Write-Host '  Entradas Java en PATH  :'
    ([string](Get-UserEnvironmentValue -Name 'Path')) -split ';' |
        Where-Object { $_ -match 'JAVA_HOME|JRE_HOME' } |
        ForEach-Object { Write-Host "    $_" }
}

function Show-Versions {
    Write-Host "`nJDK activo:" -ForegroundColor Cyan
    $jdk = Get-UserEnvironmentValue -Name 'JAVA_HOME'
    if ($jdk) { Invoke-JavaTool -Home_ $jdk -Tool 'java'; Invoke-JavaTool -Home_ $jdk -Tool 'javac' }
    else { Write-Host '  JAVA_HOME no está definido.' -ForegroundColor Yellow }

    Write-Host "`nJRE activo:" -ForegroundColor Cyan
    $jre = Get-UserEnvironmentValue -Name 'JRE_HOME'
    if ($jre) { Invoke-JavaTool -Home_ $jre -Tool 'java' }
    else { Write-Host '  JRE_HOME no está definido.' -ForegroundColor Yellow }
}

function Switch-ActiveHome {
    param([ValidateSet('jdk', 'jre')][string]$Kind)

    $variable = if ($Kind -eq 'jdk') { 'JAVA_HOME' } else { 'JRE_HOME' }
    $opciones = @(Get-ChildItem -LiteralPath $JavaRoot -Directory -Filter "$Kind-*" -ErrorAction SilentlyContinue |
        Sort-Object Name)
    if ($opciones.Count -eq 0) { Write-Host "  No hay instalaciones de $Kind en $JavaRoot" -ForegroundColor Yellow; return }

    Write-Host "`nInstalaciones de $($Kind.ToUpper()) disponibles:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $opciones.Count; $i++) { Write-Host ("  [{0}] {1}" -f ($i + 1), $opciones[$i].Name) }

    $respuesta = Read-Host 'Número a activar (Enter para cancelar)'
    if ([string]::IsNullOrWhiteSpace($respuesta)) { return }
    $n = 0
    if (-not [int]::TryParse($respuesta, [ref]$n) -or $n -lt 1 -or $n -gt $opciones.Count) {
        Write-Host '  Selección inválida.' -ForegroundColor Red; return
    }

    Set-UserEnvironmentValue -Name $variable -Value $opciones[$n - 1].FullName
    Send-EnvironmentChange
    Update-SessionEnvironment
    Write-Host "  $variable = $($opciones[$n - 1].FullName)" -ForegroundColor Green
    Write-Host '  Abra una nueva ventana de CMD/PowerShell para aplicar el cambio.'
}

function Show-Menu {
    Write-Host ''
    Write-Host '=============== Configuración de Java ===============' -ForegroundColor Cyan
    Write-Host '  1) Ver estado (JAVA_HOME, JRE_HOME, PATH)'
    Write-Host '  2) Verificar versiones (java -version / javac -version)'
    Write-Host '  3) Cambiar el JDK activo (JAVA_HOME)'
    Write-Host '  4) Cambiar el JRE activo (JRE_HOME)'
    Write-Host '  5) Abrir el editor de variables de entorno de Windows'
    Write-Host '  6) Abrir la carpeta de instalación'
    Write-Host '  0) Salir'
}

try {
    do {
        Show-Menu
        $opcion = Read-Host 'Seleccione una opción'
        switch ($opcion) {
            '1' { Show-Status }
            '2' { Show-Versions }
            '3' { Switch-ActiveHome -Kind 'jdk' }
            '4' { Switch-ActiveHome -Kind 'jre' }
            '5' { Start-Process -FilePath 'rundll32.exe' -ArgumentList 'sysdm.cpl,EditEnvironmentVariables' }
            '6' { Start-Process -FilePath 'explorer.exe' -ArgumentList "`"$JavaRoot`"" }
            '0' { }
            default { Write-Host '  Opción no válida.' -ForegroundColor Red }
        }
    } while ($opcion -ne '0')
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host 'Presione Enter para cerrar'
    exit 1
}
