# Arquitectura

```
install.cmd ──► Enable-PowerShellScripts.ps1 ──► Install-Java.ps1 ──► JavaUserEnv.psm1
                (CurrentUser + Unblock-File)        │                    (HKCU, PATH, WM_SETTINGCHANGE)
                                                    ├─► API Adoptium (versión, URL, SHA-256)
                                                    ├─► C:\Programs\Java\{jdk-*, jre-*, tools\}
                                                    └─► Escritorio\Configuración de Java.lnk ──► tools\Java-Config.ps1
```

## Decisiones de diseño

| Decisión | Motivo |
|---|---|
| Ámbito `CurrentUser` para la política de ejecución | Solo escribe en HKCU; no requiere elevación. |
| Variables en `HKCU\Environment` | Alcance de usuario; no requiere elevación. |
| PATH como `REG_EXPAND_SZ` con `%JAVA_HOME%\bin` | Cambiar de versión solo exige modificar `JAVA_HOME`. `[Environment]::SetEnvironmentVariable` escribe REG_SZ y no expandiría las referencias, por eso se usa el registro directamente. |
| Paquetes `.zip` de Temurin | Portables, sin instalador MSI ni elevación. |
| Verificación SHA-256 | Integridad de lo descargado. |
| Difusión de `WM_SETTINGCHANGE` | Los procesos nuevos (Explorador, terminales) releen el entorno sin cerrar sesión. |
| Copia de `tools\` dentro de la carpeta Java | El acceso directo sigue funcionando aunque se borre la carpeta del proyecto. |
| Carpeta de instalación con respaldo | Si `C:\Programs` no es escribible, se usa `%LOCALAPPDATA%\Programs`. |
| Funciones puras separadas | `Add-PathEntry`, `Remove-PathEntry`, `Import-DotEnv` se prueban sin tocar el registro. |

## Principios aplicados

SOLID (módulo con responsabilidades únicas), DRY (lógica de entorno compartida por instalador, desinstalador y panel), KISS (sin dependencias externas).
