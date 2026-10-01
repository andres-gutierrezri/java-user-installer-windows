<#
.SYNOPSIS
    Instala la última versión de Java (JDK y JRE) para el usuario actual de Windows 11,
    sin privilegios de administrador.

.DESCRIPTION
    Flujo de ejecución:
      1. Consulta la API de Eclipse Adoptium (Temurin) para resolver la última versión.
      2. Descarga los paquetes .zip del JDK y del JRE y verifica su SHA-256.
      3. Los extrae en <InstallRoot>\Java (por defecto C:\Programs\Java), creando la
         carpeta si no existe.
      4. Define JAVA_HOME y JRE_HOME y añade sus carpetas \bin al PATH del USUARIO
         (HKCU), de modo que 'java' y 'javac' funcionen en CMD y PowerShell.
      5. Crea en el escritorio el acceso directo "Configuración de Java".

    Nota técnica: desde Java 11 el JRE ya no se distribuye como paquete único de Oracle;
    Eclipse Adoptium sí publica imágenes JRE independientes, que es lo que se instala aquí.

.PARAMETER Version
    'latest' (última versión de características, por defecto), 'lts' (última versión
    de soporte a largo plazo) o un número de versión (por ejemplo 21).

.PARAMETER InstallRoot
    Carpeta raíz de instalación. Por defecto C:\Programs. Se crea si no existe.

.PARAMETER SkipJre
    No instala la imagen JRE independiente (solo JDK).

.PARAMETER NoShortcut
    No crea el acceso directo del escritorio.

.PARAMETER NoFallback
    Si no se puede crear InstallRoot, falla en lugar de usar %LOCALAPPDATA%\Programs.

.PARAMETER Force
    Reinstala aunque la versión ya exista en disco.

.EXAMPLE
    .\Install-Java.ps1
.EXAMPLE
    .\Install-Java.ps1 -Version lts -Force

.NOTES
    Autor   : Ingeniero Andrés Felipe Gutiérrez Rivera
    Licencia: MIT
#>

#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidatePattern('^(latest|lts|\d{1,2})$')]
    [string]$Version = 'latest',

    [ValidateNotNullOrEmpty()]
    [string]$InstallRoot = 'C:\Programs',

    [switch]$SkipJre,
    [switch]$NoShortcut,
    [switch]$NoFallback,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'JavaUserEnv.psm1') -Force

$ApiBase      = 'https://api.adoptium.net'
$ShortcutName = 'Configuración de Java.lnk'

# ---------------------------------------------------------------------------
# Valores por defecto desde .env (solo si el parámetro no se indicó explícitamente).
# ---------------------------------------------------------------------------
$envFile = Join-Path (Split-Path -Parent $PSScriptRoot) '.env'
$cfg = Import-DotEnv -FilePath $envFile
if ($cfg.Count -gt 0) {
    if (-not $PSBoundParameters.ContainsKey('Version') -and $cfg['JAVA_VERSION']) {
        if ($cfg['JAVA_VERSION'] -notmatch '^(latest|lts|\d{1,2})$') {
            throw "JAVA_VERSION inválido en .env: '$($cfg['JAVA_VERSION'])'."
        }
        $Version = $cfg['JAVA_VERSION']
    }
    if (-not $PSBoundParameters.ContainsKey('InstallRoot') -and $cfg['INSTALL_ROOT']) { $InstallRoot = $cfg['INSTALL_ROOT'] }
    if (-not $PSBoundParameters.ContainsKey('SkipJre') -and $cfg['INCLUDE_JRE'] -eq 'false') { $SkipJre = [switch]$true }
    if (-not $PSBoundParameters.ContainsKey('NoShortcut') -and $cfg['CREATE_SHORTCUT'] -eq 'false') { $NoShortcut = [switch]$true }
}

# ---------------------------------------------------------------------------
# Funciones auxiliares
# ---------------------------------------------------------------------------
function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Initialize-InstallRoot {
    <# Crea la carpeta raíz; si no hay permisos, usa %LOCALAPPDATA%\Programs (salvo -NoFallback). #>
    param([string]$Path, [bool]$AllowFallback)

    foreach ($candidato in @($Path, (Join-Path $env:LOCALAPPDATA 'Programs'))) {
        try {
            if (-not (Test-Path -LiteralPath $candidato)) {
                New-Item -ItemType Directory -Path $candidato -Force | Out-Null
                Write-Host "Carpeta creada: $candidato"
            }
            # Prueba real de escritura (las ACL pueden permitir crear carpetas pero no archivos).
            $prueba = Join-Path $candidato ".escritura-$([guid]::NewGuid().ToString('N')).tmp"
            Set-Content -LiteralPath $prueba -Value 'ok' -ErrorAction Stop
            Remove-Item -LiteralPath $prueba -Force
            return $candidato
        }
        catch {
            Write-Warning "No se puede escribir en '$candidato': $($_.Exception.Message)"
            if (-not $AllowFallback) { throw }
            $AllowFallback = $false   # el segundo candidato es el último intento
        }
    }
    throw 'No se encontró una ubicación de instalación con permisos de escritura.'
}

function Resolve-FeatureVersion {
    param([string]$Requested)

    $info = Invoke-RestMethod -Uri "$ApiBase/v3/info/available_releases" -UseBasicParsing
    switch -Regex ($Requested) {
        '^latest$' { return [int]$info.most_recent_feature_release }
        '^lts$'    { return [int]$info.most_recent_lts }
        default {
            $n = [int]$Requested
            if ($info.available_releases -notcontains $n) {
                throw "La versión $n no está disponible. Disponibles: $($info.available_releases -join ', ')."
            }
            return $n
        }
    }
}

function Get-AdoptiumAsset {
    param([int]$Feature, [ValidateSet('jdk', 'jre')][string]$ImageType)

    $uri = "$ApiBase/v3/assets/latest/$Feature/hotspot?architecture=x64&image_type=$ImageType&os=windows&vendor=eclipse"
    $assets = @(Invoke-RestMethod -Uri $uri -UseBasicParsing)
    $asset = $assets | Where-Object { $_.binary.package.link -like '*.zip' } | Select-Object -First 1
    if (-not $asset) { return $null }

    [pscustomobject]@{
        Name   = $asset.binary.package.name
        Url    = $asset.binary.package.link
        Sha256 = $asset.binary.package.checksum
        SemVer = $asset.version.semver
        SizeMB = [math]::Round($asset.binary.package.size / 1MB, 1)
    }
}

function Save-VerifiedFile {
    param([string]$Url, [string]$Destination, [string]$Sha256)

    $previo = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'   # acelera notablemente Invoke-WebRequest en PS 5.1
    try {
        for ($intento = 1; $intento -le 3; $intento++) {
            try {
                Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
                break
            }
            catch {
                if ($intento -eq 3) { throw }
                Write-Warning "Descarga fallida (intento $intento/3): $($_.Exception.Message)"
                Start-Sleep -Seconds (2 * $intento)
            }
        }
    }
    finally { $ProgressPreference = $previo }

    $hash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
    if ($hash -ne $Sha256.ToUpperInvariant()) {
        Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
        throw "La suma SHA-256 no coincide. Esperada: $Sha256 | Obtenida: $hash"
    }
    Write-Host 'Integridad verificada (SHA-256).' -ForegroundColor Green
}

function Install-JavaPackage {
    <# Descarga, verifica y extrae un paquete; devuelve la ruta final instalada. #>
    param([string]$Kind, $Asset, [string]$JavaRoot, [bool]$Overwrite)

    $tag     = $Asset.SemVer -replace '\+', '_'
    $destino = Join-Path $JavaRoot "$Kind-$tag"

    if ((Test-Path -LiteralPath $destino) -and -not $Overwrite) {
        Write-Host "$Kind ya instalado en $destino (use -Force para reinstalar)." -ForegroundColor Yellow
        return $destino
    }
    if (Test-Path -LiteralPath $destino) { Remove-Item -LiteralPath $destino -Recurse -Force }

    $zip     = Join-Path ([IO.Path]::GetTempPath()) $Asset.Name
    $staging = Join-Path $JavaRoot ".staging-$([guid]::NewGuid().ToString('N'))"
    try {
        Write-Host "Descargando $($Asset.Name) ($($Asset.SizeMB) MB)..."
        Save-VerifiedFile -Url $Asset.Url -Destination $zip -Sha256 $Asset.Sha256

        Write-Host 'Extrayendo...'
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $staging)

        $raizPaquete = Get-ChildItem -LiteralPath $staging -Directory | Select-Object -First 1
        if (-not $raizPaquete) { throw 'El paquete descargado no contiene la estructura esperada.' }
        Move-Item -LiteralPath $raizPaquete.FullName -Destination $destino

        if (-not (Test-Path -LiteralPath (Join-Path $destino 'bin\java.exe'))) {
            throw "Instalación incompleta: no se encontró bin\java.exe en $destino"
        }
        Write-Host "$Kind instalado en: $destino" -ForegroundColor Green
        return $destino
    }
    finally {
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function New-DesktopShortcut {
    param([string]$ToolScript, [string]$IconPath, [string]$WorkingDirectory)

    $escritorio = [Environment]::GetFolderPath('Desktop')   # respeta redirección a OneDrive
    $ruta = Join-Path $escritorio $ShortcutName
    $wsh  = New-Object -ComObject WScript.Shell
    $lnk  = $wsh.CreateShortcut($ruta)
    $lnk.TargetPath       = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $lnk.Arguments        = "-NoProfile -ExecutionPolicy Bypass -File `"$ToolScript`""
    $lnk.WorkingDirectory = $WorkingDirectory
    $lnk.IconLocation     = "$IconPath,0"
    $lnk.Description      = 'Panel de configuración de Java (JDK/JRE) del usuario actual'
    $lnk.Save()
    return $ruta
}

# ---------------------------------------------------------------------------
# Ejecución principal
# ---------------------------------------------------------------------------
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    if (Test-IsAdministrator) {
        Write-Warning 'Se ejecuta con privilegios elevados: las variables se registrarán para la cuenta ELEVADA, no para su usuario habitual. Se recomienda una consola normal.'
    }

    Write-Step 'Preparando la carpeta de instalación'
    $raiz     = Initialize-InstallRoot -Path $InstallRoot -AllowFallback (-not $NoFallback)
    $javaRoot = Join-Path $raiz 'Java'
    New-Item -ItemType Directory -Path $javaRoot -Force | Out-Null
    Write-Host "Ubicación: $javaRoot"

    Write-Step 'Resolviendo la versión de Java'
    $feature = Resolve-FeatureVersion -Requested $Version
    Write-Host "Versión de características seleccionada: Java $feature"

    $jdkAsset = Get-AdoptiumAsset -Feature $feature -ImageType 'jdk'
    if (-not $jdkAsset) { throw "No hay un paquete JDK .zip para Windows x64 de Java $feature." }
    $jreAsset = $null
    if (-not $SkipJre) {
        $jreAsset = Get-AdoptiumAsset -Feature $feature -ImageType 'jre'
        if (-not $jreAsset) { Write-Warning "No hay JRE independiente publicado para Java $feature; se continúa solo con el JDK." }
    }

    Write-Step 'Instalando JDK'
    $jdkPath = Install-JavaPackage -Kind 'jdk' -Asset $jdkAsset -JavaRoot $javaRoot -Overwrite $Force.IsPresent

    $jrePath = $null
    if ($jreAsset) {
        Write-Step 'Instalando JRE'
        $jrePath = Install-JavaPackage -Kind 'jre' -Asset $jreAsset -JavaRoot $javaRoot -Overwrite $Force.IsPresent
    }

    Write-Step 'Configurando variables de entorno del usuario'
    Set-UserEnvironmentValue -Name 'JAVA_HOME' -Value $jdkPath
    if ($jrePath) { Set-UserEnvironmentValue -Name 'JRE_HOME' -Value $jrePath }

    $pathUsuario = [string](Get-UserEnvironmentValue -Name 'Path')
    $pathUsuario = Add-PathEntry -Path $pathUsuario -Entry '%JAVA_HOME%\bin' -Prepend
    if ($jrePath) { $pathUsuario = Add-PathEntry -Path $pathUsuario -Entry '%JRE_HOME%\bin' }
    Set-UserEnvironmentValue -Name 'Path' -Value $pathUsuario -Expandable

    Send-EnvironmentChange
    Update-SessionEnvironment
    Write-Host "JAVA_HOME = $jdkPath"
    if ($jrePath) { Write-Host "JRE_HOME  = $jrePath" }

    Write-Step 'Copiando herramientas de configuración'
    $herramientas = Join-Path $javaRoot 'tools'
    New-Item -ItemType Directory -Path $herramientas -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'JavaUserEnv.psm1') -Destination $herramientas -Force
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Java-Config.ps1')  -Destination $herramientas -Force

    if (-not $NoShortcut) {
        Write-Step 'Creando acceso directo en el escritorio'
        $lnkPath = New-DesktopShortcut -ToolScript (Join-Path $herramientas 'Java-Config.ps1') `
                                       -IconPath (Join-Path $jdkPath 'bin\java.exe') `
                                       -WorkingDirectory $javaRoot
        Write-Host "Acceso directo: $lnkPath" -ForegroundColor Green
    }

    Write-Step 'Verificación'
    $previoEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'      # java -version escribe en stderr
    & (Join-Path $jdkPath 'bin\java.exe') -version 2>&1 | ForEach-Object { "$_" }
    & (Join-Path $jdkPath 'bin\javac.exe') -version 2>&1 | ForEach-Object { "$_" }
    $ErrorActionPreference = $previoEap

    $resuelto = Get-Command java.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($resuelto -and -not $resuelto.Source.StartsWith($javaRoot, [StringComparison]::OrdinalIgnoreCase)) {
        Write-Warning "En el PATH, 'java' resuelve primero a: $($resuelto.Source) (PATH del sistema tiene prioridad sobre el del usuario)."
    }

    Write-Host "`nInstalación finalizada. Abra una NUEVA ventana de CMD o PowerShell y ejecute: java -version" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "Fallo en la instalación: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
