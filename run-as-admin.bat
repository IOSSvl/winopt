@echo off
:: ============================================================
::  WinOpt Launcher — Avvia winopt.ps1 come Administrator
::  Doppio click per avviare, richiede conferma UAC
:: ============================================================

set "SCRIPT=%~dp0winopt.ps1"

:: Verifica esistenza script
if not exist "%SCRIPT%" (
    echo [ERRORE] winopt.ps1 non trovato in %~dp0
    pause
    exit /b 1
)

:: Lancia PowerShell con elevazione UAC
powershell -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%SCRIPT%\"'"
