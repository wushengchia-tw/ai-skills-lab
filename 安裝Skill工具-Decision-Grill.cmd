@echo off
chcp 65001 >nul
setlocal EnableExtensions DisableDelayedExpansion
title Decision-Grill Project Installer

powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand WwBDAG8AbgBzAG8AbABlAF0AOgA6AE8AdQB0AHAAdQB0AEUAbgBjAG8AZABpAG4AZwAgAD0AIAAoAE4AZQB3AC0ATwBiAGoAZQBjAHQAIABTAHkAcwB0AGUAbQAuAFQAZQB4AHQALgBVAFQARgA4AEUAbgBjAG8AZABpAG4AZwAgAC0AQQByAGcAdQBtAGUAbgB0AEwAaQBzAHQAIAAkAGYAYQBsAHMAZQApADsAIABXAHIAaQB0AGUALQBIAG8AcwB0ACAAJwAnADsAIABXAHIAaQB0AGUALQBIAG8AcwB0ACAAJwA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQAnADsAIABXAHIAaQB0AGUALQBIAG8AcwB0ACAAJwAgAEQAZQBjAGkAcwBpAG8AbgAtAEcAcgBpAGwAbAAgAAhcSGiJW92IaFYgAC0AIAB/Tyh1qooOZicAOwAgAFcAcgBpAHQAZQAtAEgAbwBzAHQAIAAnAD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9ACcAOwAgAFcAcgBpAHQAZQAtAEgAbwBzAHQAIAAnACcAOwAgAFcAcgBpAHQAZQAtAEgAbwBzAHQAIAAnABmQC1DlXXdRA2eKYgBnsGVIciAARABlAGMAaQBzAGkAbwBuAC0ARwByAGkAbABsACAAjFt0ZQeJ/YgwUgdjmlsIXEhoGv8nADsAIABXAHIAaQB0AGUALQBIAG8AcwB0ACAAJwAgACAAPAAIXEhox4yZZT5ZPgBcAC4AYQBnAGUAbgB0AHMAXABzAGsAaQBsAGwAcwBcAGQAZQBjAGkAcwBpAG8AbgAtAGcAcgBpAGwAbAAnADsAIABXAHIAaQB0AGUALQBIAG8AcwB0ACAAJwAnADsAIABXAHIAaQB0AGUALQBIAG8AcwB0ACAAJwB/Tyh1ZWtfmhr/JwA7ACAAVwByAGkAdABlAC0ASABvAHMAdAAgACcAIAAgADEALgAgADiPZVHudhlqCFxIaMeMmWU+WYR2jFt0Ze+NkV8CMCcAOwAgAFcAcgBpAHQAZQAtAEgAbwBzAHQAIAAnACAAIAAyAC4AIACiauVna3Vil2+YOnmEdoZPkG4Hgolb3YhNT25/AjAnADsAIABXAHIAaQB0AGUALQBIAG8AcwB0ACAAJwAgACAAMwAuACAAOI9lUSAAWQAgALp4jYqJW92IG/84j2VRIABOACAA1lOIbQIwJwA7ACAAVwByAGkAdABlAC0ASABvAHMAdAAgACcAIAAgADQALgAgAIlb3YiMWxBijF8M/wt6D18DZ+qB1VJXmkmLIABTAEsASQBMAEwALgBtAGQAIACEdiAAUwBIAEEALQAyADUANgACMCcAOwAgAFcAcgBpAHQAZQAtAEgAbwBzAHQAIAAnACAAIAA1AC4AIADNkbBli5VfVXKKCFxIaIR2IABDAG8AZABlAHgAIAANXHGKJk44j2VRIAAkAGQAZQBjAGkAcwBpAG8AbgAtAGcAcgBpAGwAbAACMCcAOwAgAFcAcgBpAHQAZQAtAEgAbwBzAHQAIAAnACcAOwAgAFcAcgBpAHQAZQAtAEgAbwBzAHQAIAAnAOhsD2GLTgWYGv8nADsAIABXAHIAaQB0AGUALQBIAG8AcwB0ACAAJwAgACAALQAgAA1OA2fuTzllaFHfVxZimFu5ZSAAUwBrAGkAbABsAHMAAjAnADsAIABXAHIAaQB0AGUALQBIAG8AcwB0ACAAJwAgACAALQAgAIJZnGfudhlqCFxIaPJdiVvdiAz/C3oPXwNnSFFiik9VL2YmVPRmsGUCMCcAOwAgAFcAcgBpAHQAZQAtAEgAbwBzAHQAIAAnACAAIAAtACAARABlAGMAaQBzAGkAbwBuAC0ARwByAGkAbABsACAAhk+QbhCYLYpNT7xlIABEADoAXABhAGkALQBzAGsAaQBsAGwAcwAtAGwAYQBiAAIwJwA7ACAAVwByAGkAdABlAC0ASABvAHMAdAAgACcAJwA=
if errorlevel 1 goto :failed



rem Prefer a repository next to this file, then fall back to the known location.
set "SOURCE=%~dp0skills\productivity\decision-grill"
if not exist "%SOURCE%\SKILL.md" (
    set "SOURCE=D:\ai-skills-lab\skills\productivity\decision-grill"
)

echo.
echo ============================================================
echo  Decision-Grill Project Installer
echo ============================================================
echo.

if not exist "%SOURCE%\SKILL.md" (
    echo ERROR: Decision-Grill source was not found.
    echo Expected: %SOURCE%\SKILL.md
    echo.
    echo Expected repository: D:\ai-skills-lab
    goto :failed
)

set "PROJECT=%~1"
set "ASSUME_YES=%~2"
set "NO_PAUSE=%~3"

if not defined PROJECT set /p "PROJECT=Enter the target project folder: "

if not defined PROJECT (
    echo.
    echo No project folder was entered.
    goto :cancelled
)

rem Allow a path pasted with surrounding quotation marks.
set "PROJECT=%PROJECT:"=%"

if not exist "%PROJECT%\." (
    echo.
    echo ERROR: The project folder does not exist:
    echo %PROJECT%
    goto :failed
)

set "DESTINATION=%PROJECT%\.agents\skills\decision-grill"

echo.
echo Source:
echo   %SOURCE%
echo.
echo Destination:
echo   %DESTINATION%
echo.

if exist "%DESTINATION%\." (
    echo Decision-Grill is already installed in this project.
    if /I not "%ASSUME_YES%"=="/Y" (
        choice /C YN /N /M "Update the existing installation? [Y/N]: "
        if errorlevel 2 goto :cancelled
    )
) else (
    if /I not "%ASSUME_YES%"=="/Y" (
        choice /C YN /N /M "Install Decision-Grill in this project? [Y/N]: "
        if errorlevel 2 goto :cancelled
    )
)

if not exist "%DESTINATION%\." (
    mkdir "%DESTINATION%" 2>nul
    if errorlevel 1 (
        echo.
        echo ERROR: Unable to create the destination folder.
        goto :failed
    )
)

robocopy "%SOURCE%" "%DESTINATION%" /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /XJ /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 (
    echo.
    echo ERROR: File copy failed.
    goto :failed
)

set "DG_SOURCE=%SOURCE%"
set "DG_DESTINATION=%DESTINATION%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { function Get-Sha256([string]$path) { $stream=[IO.File]::OpenRead($path); try { $sha=[Security.Cryptography.SHA256]::Create(); try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','') } finally { $sha.Dispose() } } finally { $stream.Dispose() } }; $sourceHash=Get-Sha256 (Join-Path $env:DG_SOURCE 'SKILL.md'); $installedHash=Get-Sha256 (Join-Path $env:DG_DESTINATION 'SKILL.md'); Write-Host ('Source SHA-256:    ' + $sourceHash); Write-Host ('Installed SHA-256: ' + $installedHash); if ($sourceHash -cne $installedHash) { exit 1 }; exit 0 } catch { Write-Error $_; exit 1 }"
if errorlevel 1 (
    echo.
    echo ERROR: SHA-256 verification failed.
    goto :failed
)

echo.
echo ============================================================
echo  Decision-Grill was installed successfully.
echo ============================================================
echo.
echo Installed at:
echo   %DESTINATION%
echo.
echo Open a new Codex conversation for this project and enter:
echo   $decision-grill
echo.
if /I not "%NO_PAUSE%"=="/NOPAUSE" pause
exit /b 0

:cancelled
echo.
echo Installation cancelled. No files were copied.
echo.
if /I not "%NO_PAUSE%"=="/NOPAUSE" pause
exit /b 1

:failed
echo.
echo Installation did not complete.
echo.
if /I not "%NO_PAUSE%"=="/NOPAUSE" pause
exit /b 1
