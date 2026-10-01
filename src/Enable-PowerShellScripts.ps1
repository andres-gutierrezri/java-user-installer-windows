<#
.SYNOPSIS
    Habilita la ejecución de scripts de PowerShell para la cuenta local actual,
    sin privilegios de administrador.

.DESCRIPTION
    Establece la política de ejecución en el ámbito CurrentUser (HKCU), que no
    requiere elevación. Además desbloquea (Unblock-File) los scripts de este
    proyecto, ya que los archivos descargados de Internet (por ejemplo, el .zip
    de GitHub) llevan la marca "Mark of the Web" y RemoteSigned los bloquearía.

.PARAMETER Policy
    Política a aplicar en el ámbito CurrentUser. Por defecto: RemoteSigned.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\src\Enable-PowerShellScripts.ps1

.NOTES
    Autor   : Ingeniero Andrés Felipe Gutiérrez Rivera
    Licencia: MIT
#>

#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('RemoteSigned', 'Unrestricted')]
    [string]$Policy = 'RemoteSigned'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Política actual (CurrentUser): $(Get-ExecutionPolicy -Scope CurrentUser)"

    # No requiere administrador: el ámbito CurrentUser solo escribe en HKCU.
    Set-ExecutionPolicy -ExecutionPolicy $Policy -Scope CurrentUser -Force
    Write-Host "Política establecida (CurrentUser): $(Get-ExecutionPolicy -Scope CurrentUser)" -ForegroundColor Green

    # Desbloquear los scripts del proyecto (marca Zone.Identifier de archivos descargados).
    $raiz = Split-Path -Parent $PSScriptRoot
    Get-ChildItem -LiteralPath $raiz -Recurse -File -Include '*.ps1', '*.psm1' |
        Unblock-File
    Write-Host 'Scripts del proyecto desbloqueados.' -ForegroundColor Green

    # Una directiva de grupo (MachinePolicy/UserPolicy) tiene precedencia sobre CurrentUser.
    $gpo = Get-ExecutionPolicy -List |
        Where-Object { $_.Scope -in 'MachinePolicy', 'UserPolicy' -and $_.ExecutionPolicy -ne 'Undefined' }
    if ($gpo) {
        Write-Warning ('Una directiva de grupo controla la ejecución de scripts y anula este ajuste: ' +
            (($gpo | ForEach-Object { "$($_.Scope)=$($_.ExecutionPolicy)" }) -join ', '))
        Write-Warning 'Consulte al administrador del equipo o use el lanzador install.cmd (usa -ExecutionPolicy Bypass solo por proceso).'
    }
    exit 0
}
catch {
    Write-Host "No fue posible habilitar la ejecución de scripts: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
