# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y versionado [SemVer](https://semver.org/lang/es/).

## [1.0.0] - 2026-10-01
### Añadido
- Habilitación de scripts de PowerShell en el ámbito `CurrentUser` (sin administrador).
- Instalación de JDK y JRE (Eclipse Temurin) con resolución dinámica de la última versión y verificación SHA-256.
- Variables de usuario `JAVA_HOME` y `JRE_HOME`; entradas en el `PATH` del usuario (REG_EXPAND_SZ).
- Acceso directo "Configuración de Java" en el escritorio y panel interactivo.
- Lanzadores `install.cmd` / `uninstall.cmd`, desinstalador y pruebas.
