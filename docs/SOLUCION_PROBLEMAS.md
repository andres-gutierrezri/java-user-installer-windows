# Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| `java` no se reconoce | La consola se abrió antes de instalar | Abra una **nueva** ventana de CMD/PowerShell. |
| `java -version` muestra otra versión | Hay otro Java en el PATH del **sistema** (tiene prioridad) | Ejecute `where java`; ajuste el PATH del sistema (requiere administrador) o invoque `%JAVA_HOME%\bin\java`. |
| "La ejecución de scripts está deshabilitada" | Política restrictiva | Use `install.cmd` (Bypass por proceso) o ejecute `Enable-PowerShellScripts.ps1`. |
| El script sigue bloqueado | Archivo con *Mark of the Web* | `Get-ChildItem -Recurse *.ps1,*.psm1 \| Unblock-File` |
| Una GPO anula la política | `MachinePolicy`/`UserPolicy` definidas | Consulte `Get-ExecutionPolicy -List`; use `install.cmd`. |
| No se puede crear `C:\Programs` | ACL restringida por la organización | El instalador usa `%LOCALAPPDATA%\Programs` (o `-InstallRoot` otra ruta). |
| Suma SHA-256 no coincide | Descarga corrupta o proxy que altera el contenido | Reintente; revise el proxy/antivirus. |
| Error TLS / 504 | Red o proxy | Reintente (el script reintenta 3 veces); verifique acceso a `api.adoptium.net`. |
| El acceso directo no aparece | Escritorio redirigido (OneDrive) | Se crea en la ruta real del escritorio (`[Environment]::GetFolderPath('Desktop')`). |
