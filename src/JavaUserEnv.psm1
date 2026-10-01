<#
.SYNOPSIS
    Módulo de utilidades para administrar variables de entorno del USUARIO ACTUAL.

.DESCRIPTION
    Todas las operaciones se limitan a HKCU:\Environment, por lo que no requieren
    privilegios de administrador (principio de mínimo privilegio).

    Se escribe directamente en el registro porque [Environment]::SetEnvironmentVariable
    guarda los valores como REG_SZ y, en consecuencia, las referencias del tipo
    %JAVA_HOME% dentro de PATH no se expandirían. PATH debe ser REG_EXPAND_SZ.

.NOTES
    Autor   : Ingeniero Andrés Felipe Gutiérrez Rivera
    Licencia: MIT
#>

#Requires -Version 5.1
Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------
# Funciones puras (sin efectos secundarios): fáciles de probar de forma aislada.
# ---------------------------------------------------------------------------

function Add-PathEntry {
    <#
    .SYNOPSIS
        Agrega una entrada a una cadena de PATH sin duplicarla (sin distinguir mayúsculas).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()][AllowNull()][string]$Path,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Entry,
        [switch]$Prepend
    )

    $items = @(([string]$Path) -split ';' | Where-Object { $_.Trim() -ne '' })
    $normalizada = $Entry.TrimEnd('\')
    $existe = @($items | Where-Object { $_.TrimEnd('\') -ieq $normalizada }).Count -gt 0

    if (-not $existe) {
        if ($Prepend) { $items = @($Entry) + $items } else { $items = $items + @($Entry) }
    }
    return ($items -join ';')
}

function Remove-PathEntry {
    <#
    .SYNOPSIS
        Elimina una entrada de una cadena de PATH (sin distinguir mayúsculas).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()][AllowNull()][string]$Path,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Entry
    )

    $normalizada = $Entry.TrimEnd('\')
    $items = @(([string]$Path) -split ';' |
        Where-Object { $_.Trim() -ne '' -and $_.TrimEnd('\') -ine $normalizada })
    return ($items -join ';')
}

function Import-DotEnv {
    <#
    .SYNOPSIS
        Lee un archivo .env sencillo (CLAVE=valor) y devuelve una tabla hash.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][string]$FilePath)

    $resultado = @{}
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { return $resultado }

    foreach ($linea in Get-Content -LiteralPath $FilePath -Encoding UTF8) {
        $texto = $linea.Trim()
        if ($texto -eq '' -or $texto.StartsWith('#')) { continue }
        $partes = $texto -split '=', 2
        if ($partes.Count -ne 2) { continue }
        $resultado[$partes[0].Trim()] = $partes[1].Trim().Trim('"').Trim("'")
    }
    return $resultado
}

# ---------------------------------------------------------------------------
# Funciones con efectos sobre el sistema (solo HKCU y el proceso actual).
# ---------------------------------------------------------------------------

function Test-IsAdministrator {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $identidad = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identidad)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-UserEnvironmentValue {
    <#
    .SYNOPSIS
        Lee un valor de HKCU:\Environment SIN expandir las referencias %VAR%.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)

    $clave = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $false)
    if ($null -eq $clave) { return $null }
    try {
        return $clave.GetValue($Name, $null,
            [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    }
    finally { $clave.Close() }
}

function Set-UserEnvironmentValue {
    <#
    .SYNOPSIS
        Escribe un valor en HKCU:\Environment (REG_SZ, o REG_EXPAND_SZ con -Expandable).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Value,
        [switch]$Expandable
    )

    $tipo = if ($Expandable) { [Microsoft.Win32.RegistryValueKind]::ExpandString }
            else             { [Microsoft.Win32.RegistryValueKind]::String }

    if ($PSCmdlet.ShouldProcess("HKCU:\Environment\$Name", "Establecer '$Value'")) {
        $clave = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
        try { $clave.SetValue($Name, $Value, $tipo) }
        finally { $clave.Close() }
    }
}

function Remove-UserEnvironmentValue {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$Name)

    if ($PSCmdlet.ShouldProcess("HKCU:\Environment\$Name", 'Eliminar variable')) {
        $clave = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
        try { $clave.DeleteValue($Name, $false) }
        finally { $clave.Close() }
    }
}

function Send-EnvironmentChange {
    <#
    .SYNOPSIS
        Difunde WM_SETTINGCHANGE para que el Explorador y los procesos nuevos
        relean las variables de entorno sin cerrar sesión.
    #>
    [CmdletBinding()]
    param()

    if (-not ('JavaUserEnv.NativeMethods' -as [type])) {
        Add-Type -Namespace 'JavaUserEnv' -Name 'NativeMethods' -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true, CharSet = System.Runtime.InteropServices.CharSet.Auto)]
public static extern System.IntPtr SendMessageTimeout(
    System.IntPtr hWnd, uint Msg, System.UIntPtr wParam, string lParam,
    uint fuFlags, uint uTimeout, out System.UIntPtr lpdwResult);
'@
    }

    $HWND_BROADCAST = [IntPtr]0xffff
    $WM_SETTINGCHANGE = 0x001A
    $SMTO_ABORTIFHUNG = 0x0002
    $resultado = [UIntPtr]::Zero
    [void][JavaUserEnv.NativeMethods]::SendMessageTimeout(
        $HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, 'Environment',
        $SMTO_ABORTIFHUNG, 5000, [ref]$resultado)
}

function Update-SessionEnvironment {
    <#
    .SYNOPSIS
        Sincroniza JAVA_HOME, JRE_HOME y PATH de la sesión actual con el registro,
        para poder usar 'java' de inmediato en la misma ventana.
    #>
    [CmdletBinding()]
    param()

    foreach ($nombre in 'JAVA_HOME', 'JRE_HOME') {
        $valor = Get-UserEnvironmentValue -Name $nombre
        [Environment]::SetEnvironmentVariable($nombre, $valor, 'Process')
    }

    $maquina = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $usuario = [Environment]::ExpandEnvironmentVariables([string](Get-UserEnvironmentValue -Name 'Path'))
    [Environment]::SetEnvironmentVariable('Path', "$maquina;$usuario", 'Process')
}

Export-ModuleMember -Function `
    Add-PathEntry, Remove-PathEntry, Import-DotEnv, Test-IsAdministrator, `
    Get-UserEnvironmentValue, Set-UserEnvironmentValue, Remove-UserEnvironmentValue, `
    Send-EnvironmentChange, Update-SessionEnvironment
