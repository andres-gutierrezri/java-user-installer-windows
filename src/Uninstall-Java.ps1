<#
.SYNOPSIS
    Revierte la instalación de Java realizada por Install-Java.ps1 (solo el usuario actual).

.DESCRIPTION
    Elimina JAVA_HOME, JRE_HOME y sus entradas en el PATH del usuario, borra la carpeta
    <InstallRoot>\Java y retira el acceso directo del escritorio. No toca PATH del sistema
    ni instalaciones de Java ajenas a este proyecto.

.PARAMETER JavaRoot
    Carpeta Java a eliminar. Si se omite, se deduce de JAVA_HOME; en su defecto, C:\Programs\Java.

.PARAMETER KeepFiles
    Conserva los archivos en disco y solo limpia variables y acceso directo.

.PARAMETER Force
    No solicita confirmación.

.EXAMPLE
    .\Uninstall-Java.ps1 -WhatIf

.NOTES
    Autor   : Ingeniero Andrés Felipe Gutiérrez Rivera
    Licencia: MIT
#>

#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$JavaRoot,
    [switch]$KeepFiles,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'JavaUserEnv.psm1') -Force

try {
    if (-not $JavaRoot) {
        $jh = Get-UserEnvironmentValue -Name 'JAVA_HOME'
        $JavaRoot = if ($jh) { Split-Path -Parent $jh } else { 'C:\Programs\Java' }
    }
    Write-Host "Carpeta Java objetivo: $JavaRoot"

    if (-not $Force -and -not $WhatIfPreference) {
        $r = Read-Host "Se eliminarán variables, PATH, acceso directo$(if (-not $KeepFiles) { ' y la carpeta anterior' }). ¿Continuar? (s/N)"
        if ($r -notmatch '^(s|si|sí|y|yes)$') { Write-Host 'Operación cancelada.'; exit 0 }
    }

    # 1) PATH del usuario
    $path = [string](Get-UserEnvironmentValue -Name 'Path')
    foreach ($entrada in '%JAVA_HOME%\bin', '%JRE_HOME%\bin') { $path = Remove-PathEntry -Path $path -Entry $entrada }
    Set-UserEnvironmentValue -Name 'Path' -Value $path -Expandable

    # 2) Variables
    foreach ($nombre in 'JAVA_HOME', 'JRE_HOME') { Remove-UserEnvironmentValue -Name $nombre }

    # 3) Acceso directo
    $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Configuración de Java.lnk'
    if (Test-Path -LiteralPath $lnk) {
        if ($PSCmdlet.ShouldProcess($lnk, 'Eliminar acceso directo')) { Remove-Item -LiteralPath $lnk -Force }
    }

    # 4) Archivos
    if (-not $KeepFiles -and (Test-Path -LiteralPath $JavaRoot)) {
        if ($PSCmdlet.ShouldProcess($JavaRoot, 'Eliminar carpeta')) {
            Remove-Item -LiteralPath $JavaRoot -Recurse -Force
            Write-Host "Carpeta eliminada: $JavaRoot"
        }
    }

    if (-not $WhatIfPreference) {
        Send-EnvironmentChange
        Update-SessionEnvironment
    }
    Write-Host 'Desinstalación finalizada. Abra una nueva ventana de consola.' -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "Fallo en la desinstalación: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
