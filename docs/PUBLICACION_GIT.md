# Publicación en GitHub y GitLab (comando por comando)

Cuentas del autor: GitHub `andres-gutierrezri` · GitLab `andres.gutierrezri`.
Los comandos están escritos para **PowerShell en Windows 11**; los de Git son idénticos en CMD.

## 1. Preparación

```powershell
git --version                       # verificar que Git está instalado
winget install --id Git.Git -e --scope user   # si no lo está (instalación por usuario)
```

## 2. Inicialización del repositorio local

```powershell
cd C:\ruta\a\java-user-installer-windows
git init -b main                    # crea el repositorio con la rama principal 'main'
```

## 3. Configuración de usuario

```powershell
git config --global user.name  "Andrés Felipe Gutiérrez Rivera"
git config --global user.email "felipe.gutierrezri@gmail.com"
git config --global core.autocrlf false     # respeta .gitattributes (CRLF en .cmd/.ps1)
git config --global init.defaultBranch main
git config --list --show-origin | Select-String "user\."
```

> Si desea ocultar su correo en GitHub, use la dirección `ID+usuario@users.noreply.github.com` de *Settings → Emails*.

## 4. Preparación y confirmación inicial

```powershell
git status
git add .
git status                          # revisar qué se incluirá (.env NO debe aparecer)
git commit -m "feat: version inicial del instalador de Java para Windows 11 sin administrador"
git log --oneline
```

## 5. Creación del repositorio remoto (interfaz web)

**GitHub:** <https://github.com/new> → *Repository name*: `java-user-installer-windows` → *Public/Private* → **no** marcar *Add README/.gitignore/license* (ya existen) → *Create repository*.

**GitLab:** <https://gitlab.com/projects/new> → *Create blank project* → *Project name*: `java-user-installer-windows` → desmarcar *Initialize repository with a README* → *Create project*.

## 6. Vinculación del remoto y publicación de la rama principal

```powershell
git remote add origin https://github.com/andres-gutierrezri/java-user-installer-windows.git
git remote -v
git branch -M main
git push -u origin main
```

## 7. Doble remoto (GitHub + GitLab sincronizados)

**Opción A — un solo `origin` con dos destinos de push** (un único `git push` publica en ambos):

```powershell
git remote set-url --add --push origin https://github.com/andres-gutierrezri/java-user-installer-windows.git
git remote set-url --add --push origin https://gitlab.com/andres.gutierrezri/java-user-installer-windows.git
git remote -v                       # 'origin' mostrará dos líneas (push)
git push -u origin main
```

> Al usar `--add --push`, la primera vez debe añadir **ambas** URL (como arriba), porque la primera sustituye al destino implícito.

**Opción B — dos remotos con nombre (más explícita):**

```powershell
git remote add github https://github.com/andres-gutierrezri/java-user-installer-windows.git
git remote add gitlab https://gitlab.com/andres.gutierrezri/java-user-installer-windows.git
git push -u github main
git push -u gitlab main
# Alias para publicar en ambos con un solo comando:
git config --global alias.pushall '!git push github --follow-tags && git push gitlab --follow-tags'
git pushall
```

## 8. Autenticación

### 8.1 SSH (recomendada)

```powershell
ssh-keygen -t ed25519 -C "felipe.gutierrezri@gmail.com"      # Enter para aceptar la ruta por defecto; use una frase de paso
Get-Service ssh-agent | Select-Object Status,StartType        # el servicio puede estar deshabilitado y requerir administrador una sola vez
ssh-add $env:USERPROFILE\.ssh\id_ed25519
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | Set-Clipboard   # copia la clave PÚBLICA
```

- GitHub: *Settings → SSH and GPG keys → New SSH key* → pegar.
- GitLab: *Preferences → SSH Keys → Add new key* → pegar.

```powershell
ssh -T git@github.com
ssh -T git@gitlab.com
git remote set-url github git@github.com:andres-gutierrezri/java-user-installer-windows.git
git remote set-url gitlab git@gitlab.com:andres.gutierrezri/java-user-installer-windows.git
```

> Si no puede iniciar `ssh-agent` sin administrador, omita `ssh-add`: OpenSSH le pedirá la frase de paso en cada conexión.

### 8.2 Token de acceso personal (PAT) por HTTPS

1. GitHub: *Settings → Developer settings → Personal access tokens* → crear token con alcance `repo` y caducidad corta.
   GitLab: *Preferences → Access tokens* → alcances `read_repository` y `write_repository`.
2. Al ejecutar `git push`, use su usuario y **el token como contraseña**. Git Credential Manager (incluido en Git for Windows) lo almacenará en el Administrador de credenciales de Windows.

```powershell
git config --global credential.helper manager
```

> Nunca incluya el token en un archivo versionado, en `.env` publicado ni en la URL del remoto.

## 9. Buenas prácticas

### 9.1 Ramificación (Git Flow simplificado)

```powershell
git switch -c develop                         # rama de integración
git switch -c feature/panel-configuracion develop
# ... trabajo ...
git switch develop
git merge --no-ff feature/panel-configuracion
git switch -c release/1.1.0 develop           # preparación de versión
git switch main; git merge --no-ff release/1.1.0
git switch -c hotfix/corrige-path main        # correcciones urgentes
```

### 9.2 Conventional Commits

```
<tipo>[ámbito opcional]: <descripción>
feat(install): agrega parámetro -Version lts
fix(path): conserva REG_EXPAND_SZ al escribir el PATH
docs(readme): aclara el uso de -NoFallback
test: agrega pruebas de Remove-PathEntry
chore: actualiza .gitignore
feat!: cambia la ubicación por defecto de instalación   # '!' = cambio incompatible
```

### 9.3 Etiquetado SemVer

```powershell
git tag -a v1.0.0 -m "Versión 1.0.0"
git push github v1.0.0
git push gitlab v1.0.0
git tag --list "v*"
```

Incremente **MAJOR** (cambios incompatibles), **MINOR** (funciones compatibles) o **PATCH** (correcciones), y mantenga `VERSION` y `CHANGELOG.md` alineados con la etiqueta.
