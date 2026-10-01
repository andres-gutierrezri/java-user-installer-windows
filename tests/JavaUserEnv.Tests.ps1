<#
.SYNOPSIS
    Pruebas unitarias de las funciones puras del módulo JavaUserEnv (no tocan el registro).
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\JavaUserEnv.Tests.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\src\JavaUserEnv.psm1') -Force

$script:fallos = 0
function Assert-Equal {
    param([string]$Nombre, $Esperado, $Obtenido)
    if ($Esperado -ceq $Obtenido) { Write-Host "[OK]    $Nombre" -ForegroundColor Green }
    else {
        Write-Host "[FALLO] $Nombre`n        esperado: '$Esperado'`n        obtenido: '$Obtenido'" -ForegroundColor Red
        $script:fallos++
    }
}

# Add-PathEntry
Assert-Equal 'Agrega al final'            'C:\a;C:\b'            (Add-PathEntry -Path 'C:\a' -Entry 'C:\b')
Assert-Equal 'Agrega al inicio (Prepend)' '%JAVA_HOME%\bin;C:\a' (Add-PathEntry -Path 'C:\a' -Entry '%JAVA_HOME%\bin' -Prepend)
Assert-Equal 'No duplica (ignora caso)'   'C:\a;C:\b'            (Add-PathEntry -Path 'C:\a;C:\b' -Entry 'c:\B')
Assert-Equal 'No duplica (barra final)'   'C:\a;C:\b'            (Add-PathEntry -Path 'C:\a;C:\b' -Entry 'C:\b\')
Assert-Equal 'PATH vacío'                 'C:\x'                 (Add-PathEntry -Path '' -Entry 'C:\x')
Assert-Equal 'PATH nulo'                  'C:\x'                 (Add-PathEntry -Path $null -Entry 'C:\x')
Assert-Equal 'Ignora segmentos vacíos'    'C:\a;C:\b'            (Add-PathEntry -Path 'C:\a;;' -Entry 'C:\b')

# Remove-PathEntry
Assert-Equal 'Quita una entrada'          'C:\a;C:\c'            (Remove-PathEntry -Path 'C:\a;C:\b;C:\c' -Entry 'C:\b')
Assert-Equal 'Quita ignorando caso'       'C:\a'                 (Remove-PathEntry -Path 'C:\a;%JAVA_HOME%\bin' -Entry '%java_home%\BIN')
Assert-Equal 'Entrada inexistente'        'C:\a'                 (Remove-PathEntry -Path 'C:\a' -Entry 'C:\z')
Assert-Equal 'Resultado vacío'            ''                     (Remove-PathEntry -Path 'C:\a' -Entry 'C:\a')

# Import-DotEnv
$tmp = Join-Path ([IO.Path]::GetTempPath()) "dotenv-$([guid]::NewGuid().ToString('N')).env"
Set-Content -LiteralPath $tmp -Value @('# comentario', 'JAVA_VERSION=lts', 'INSTALL_ROOT="C:\Programs"', '', 'INCLUDE_JRE = false') -Encoding UTF8
$cfg = Import-DotEnv -FilePath $tmp
Remove-Item -LiteralPath $tmp -Force
Assert-Equal 'DotEnv: clave simple'       'lts'                  $cfg['JAVA_VERSION']
Assert-Equal 'DotEnv: quita comillas'     'C:\Programs'          $cfg['INSTALL_ROOT']
Assert-Equal 'DotEnv: espacios'           'false'                $cfg['INCLUDE_JRE']
Assert-Equal 'DotEnv: archivo inexistente' 0                     ((Import-DotEnv -FilePath 'Z:\no-existe.env').Count)

if ($script:fallos -gt 0) { Write-Host "`n$($script:fallos) prueba(s) fallida(s)." -ForegroundColor Red; exit 1 }
Write-Host "`nTodas las pruebas unitarias pasaron." -ForegroundColor Green
exit 0
