@echo off

set PORT=8080

net session >nul 2>&1
if errorlevel 1 (
  echo Ce script doit etre lance en administrateur.
  PAUSE
  exit /b 1
)

ECHO ========================================================
ECHO Open FW
ECHO ========================================================
netsh http add urlacl url=http://+:%PORT%/ user=Everyone >nul 2>&1
netsh advfirewall firewall delete rule name="HTTP %PORT%" >nul 2>&1
netsh advfirewall firewall add rule name="HTTP %PORT%" dir=in action=allow protocol=TCP localport=%PORT% >nul

ECHO ========================================================
ECHO Start server
ECHO ========================================================
powershell -f "%~dp0server.ps1" -Port %PORT%

ECHO ========================================================
ECHO Close FW
ECHO ========================================================
netsh advfirewall firewall delete rule name="HTTP %PORT%" >nul
netsh http delete urlacl url=http://+:8080/.

PAUSE
