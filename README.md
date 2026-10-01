# java-user-installer-windows

Instalador de **Java (JDK + JRE)** para **Windows 11** mediante **PowerShell y CMD**, en una **cuenta local sin privilegios de administrador**.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-11-0078D4?logo=windows11&logoColor=white)
![Java](https://img.shields.io/badge/Java-Temurin%20(Adoptium)-ED8B00?logo=openjdk&logoColor=white)
![Version](https://img.shields.io/badge/version-1.0.0-green)
![License](https://img.shields.io/badge/license-MIT-blue)

Qué hace, en orden:

1. Habilita la ejecución de scripts de PowerShell para el usuario actual (`CurrentUser`).
2. Resuelve la última versión de Java con la API de Eclipse Adoptium y verifica la integridad (SHA-256).
3. Instala JDK y JRE en `C:\Programs\Java\` (crea `C:\Programs` si no existe).
4. Crea `JAVA_HOME` y `JRE_HOME` y agrega `%JAVA_HOME%\bin` y `%JRE_HOME%\bin` al `PATH` **del usuario**.
5. Crea en el escritorio el acceso directo **Configuración de Java**.

## Tabla de contenidos

- [Requisitos previos](#requisitos-previos)
- [Instalación paso a paso](#instalación-paso-a-paso)
- [Entorno virtual y dependencias](#entorno-virtual-y-dependencias)
- [Configuración de variables de entorno](#configuración-de-variables-de-entorno)
- [Migraciones y datos iniciales](#migraciones-y-datos-iniciales)
- [Ejecución](#ejecución)
- [Pruebas](#pruebas)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Aclaraciones técnicas importantes](#aclaraciones-técnicas-importantes)
- [Desinstalación](#desinstalación)
- [Autor](#autor)
- [Licencia](#licencia)

## Requisitos previos

| Requisito | Detalle |
|---|---|
| Sistema operativo | Windows 11 (x64) |
| PowerShell | Windows PowerShell 5.1 (incluido en Windows 11) |
| Red | Acceso HTTPS a `api.adoptium.net` y `github.com` |
| Espacio en disco | ~ 600 MB libres (JDK + JRE descomprimidos) |
| Permisos | Cuenta de usuario estándar (**no** se requiere administrador) |
| Escritura en `C:\` | La ACL predeterminada de Windows permite a los usuarios crear carpetas en `C:\`. Si el equipo la restringió, el instalador usa `%LOCALAPPDATA%\Programs` (desactivable con `-NoFallback`) |

## Instalación paso a paso

```powershell
# 1. Clonar el repositorio (o descargar el .zip y extraerlo)
git clone https://github.com/andres-gutierrezri/java-user-installer-windows.git
cd java-user-installer-windows
```

**Opción A — desde CMD (recomendada):**

```bat
install.cmd
```

**Opción B — desde PowerShell:**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\src\Enable-PowerShellScripts.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\src\Install-Java.ps1
```

Parámetros opcionales (valen para `install.cmd` y para `Install-Java.ps1`):

| Parámetro | Descripción | Ejemplo |
|---|---|---|
| `-Version` | `latest` (por defecto), `lts` o un número | `-Version lts` / `-Version 21` |
| `-InstallRoot` | Carpeta raíz (se crea si no existe) | `-InstallRoot D:\Programs` |
| `-SkipJre` | Instala solo el JDK | |
| `-NoShortcut` | No crea el acceso directo | |
| `-NoFallback` | Falla si no puede crear `InstallRoot` | |
| `-Force` | Reinstala aunque exista la versión | |

## Entorno virtual y dependencias

Este proyecto es **PowerShell/CMD puro**: no usa Python ni Node.js, por lo que **no requiere `venv` ni `requirements.txt`/`package.json`**. No hay dependencias que instalar; solo se usan componentes incluidos en Windows 11 (PowerShell 5.1, .NET Framework, `WScript.Shell`).

## Configuración de variables de entorno

Opcionalmente, copie `.env.example` como `.env` para fijar valores por defecto:

```powershell
Copy-Item .env.example .env
```

Los parámetros de línea de comandos siempre prevalecen sobre `.env`. Variables que el instalador **crea en su cuenta**:

| Variable | Valor | Dónde |
|---|---|---|
| `JAVA_HOME` | `C:\Programs\Java\jdk-<versión>` | `HKCU\Environment` (REG_SZ) |
| `JRE_HOME` | `C:\Programs\Java\jre-<versión>` | `HKCU\Environment` (REG_SZ) |
| `Path` (usuario) | `%JAVA_HOME%\bin;…;%JRE_HOME%\bin` | `HKCU\Environment` (REG_EXPAND_SZ) |

## Migraciones y datos iniciales

No aplica (no hay base de datos).

## Ejecución

Tras instalar, abra una **nueva** ventana de CMD o PowerShell:

```bat
java -version
javac -version
echo %JAVA_HOME%
```

Haga doble clic en **Configuración de Java** (escritorio) para abrir el panel: estado, versiones, cambio de JDK/JRE activo, editor de variables de entorno y carpeta de instalación.

## Pruebas

```powershell
# Pruebas unitarias de las funciones puras (no modifican el sistema)
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\JavaUserEnv.Tests.ps1

# Pruebas de aceptación posteriores a la instalación (consola NUEVA)
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Installation.ps1
```

```bat
:: Verificación desde CMD puro (ventana nueva)
tests\verify-java.cmd
```

## Estructura del proyecto

```
java-user-installer-windows/
├── install.cmd                      # Lanzador CMD: habilita scripts + instala
├── uninstall.cmd                    # Lanzador CMD de desinstalación
├── src/
│   ├── Enable-PowerShellScripts.ps1 # Política CurrentUser + Unblock-File
│   ├── Install-Java.ps1             # Descarga, verifica, instala, variables, acceso directo
│   ├── Java-Config.ps1              # Panel de configuración (destino del acceso directo)
│   ├── Uninstall-Java.ps1           # Reversión completa
│   └── JavaUserEnv.psm1             # Módulo: PATH, registro HKCU, WM_SETTINGCHANGE
├── tests/
│   ├── JavaUserEnv.Tests.ps1        # Pruebas unitarias
│   ├── Test-Installation.ps1        # Pruebas de aceptación
│   └── verify-java.cmd              # Verificación desde CMD
├── docs/
│   ├── ARQUITECTURA.md
│   ├── PUBLICACION_GIT.md           # GitHub + GitLab (doble remoto, SSH, PAT)
│   └── SOLUCION_PROBLEMAS.md
├── .env.example  .gitignore  .gitattributes
├── CHANGELOG.md  VERSION  LICENSE  README.md
```

## Aclaraciones técnicas importantes

- **Distribución:** se instala **Eclipse Temurin** (Adoptium), build de OpenJDK de código abierto, porque publica JDK **y** JRE en `.zip` portables que no requieren instalador ni administrador.
- **"Última versión":** por defecto es la última versión de características (hoy Java 27). Si necesita soporte a largo plazo, use `-Version lts` (hoy Java 25).
- **JRE:** desde Java 11 los JRE separados ya no son el modelo de distribución de Oracle; Adoptium sí los publica. Si para una versión no existe JRE, el instalador continúa solo con el JDK.
- **Acceso directo "Configuración de Java":** el *Java Control Panel* clásico solo existe en el JRE 8 de Oracle. Para Java moderno el acceso directo abre un panel propio (`Java-Config.ps1`).
- **Prioridad del PATH:** Windows evalúa primero el PATH del sistema y luego el del usuario. Si existe otro Java en el PATH del sistema (p. ej. `javapath`), `java` podría resolver a ese; el instalador lo detecta y lo advierte.
- **Directivas de grupo:** si una GPO fija la política de ejecución, `CurrentUser` no puede anularla; `install.cmd` funciona igualmente porque usa `-ExecutionPolicy Bypass` solo para su proceso.

## Desinstalación

```bat
uninstall.cmd -WhatIf   :: simulación
uninstall.cmd           :: con confirmación
```

## Autor

**Ingeniero Andrés Felipe Gutiérrez Rivera**

- GitHub: <https://github.com/andres-gutierrezri>
- GitLab: <https://gitlab.com/andres.gutierrezri>
- LinkedIn: <https://www.linkedin.com/in/felipe-gutierrezri>

## Licencia

Distribuido bajo la licencia [MIT](LICENSE). Java (Eclipse Temurin) se distribuye bajo sus propias licencias (GPLv2 + Classpath Exception).
