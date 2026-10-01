@echo off
rem ===========================================================================
rem  uninstall.cmd - Revierte la instalacion de Java (solo usuario actual)
rem  Uso:  uninstall.cmd [-KeepFiles] [-Force] [-WhatIf]
rem  Autor: Ingeniero Andres Felipe Gutierrez Rivera - Licencia MIT
rem ===========================================================================
setlocal
set "RAIZ=%~dp0"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%RAIZ%src\Uninstall-Java.ps1" %*
exit /b %errorlevel%
