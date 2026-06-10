@echo off
rem =========================================================================
rem HP Enterprise Fleet Deployment Bootstrap Launcher
rem v1.5.4 - Dynamic Production Infrastructure Delivery Wrapper
rem =========================================================================
setlocal enabledelayedexpansion

title HP Fleet Deployment Engine

echo =========================================================================
echo             HP ENTERPRISE AUTOMATED FLEET DEPLOYMENT ENGINE             
echo =========================================================================

set "ROOT=%~dp0"

rem -------------------------------------------------------------------------
rem Security Validation: Verify Administrative Context
rem -------------------------------------------------------------------------
echo [SYSTEM] Validating security tokens...
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [CRITICAL] Elevated administrative privileges are required.
    echo [ACTION] Please relaunch this script wrapper using 'Run as Administrator'.
    echo =========================================================================
    pause
    exit /b 1
)

rem -------------------------------------------------------------------------
rem Dependency Sync: Dynamic Local Runtime Environment Verification
rem -------------------------------------------------------------------------
if not exist "C:\Program Files\HP\HP Client Management Script Library" (
    echo [DEPENDENCY] HP Client Management Script Library missing.
    
    rem Dynamically scan for any version matching the pattern in the Tools folder
    set "CMSL_INSTALLER="
    for %%F in ("%ROOT%Tools\hp-cmsl-*.exe") do (
        set "CMSL_INSTALLER=%%F"
    )
    
    if defined CMSL_INSTALLER (
        echo [INSTALL] Located modern package payload: !CMSL_INSTALLER!
        echo [INSTALL] Executing localized silent setup for HP CMSL framework...
        "!CMSL_INSTALLER!" /quiet /norestart
        echo [SUCCESS] Runtime dependencies registered.
    ) else (
        echo [WARNING] Offline installer missing from \Tools folder. 
        echo [INFO] Pipeline will attempt online module sync within PowerShell context.
    )
)

rem -------------------------------------------------------------------------
rem Environmental Sync: Validate Network Reachability
rem -------------------------------------------------------------------------
echo [NETWORK] Verifying endpoint path to global update infrastructure...
ping -n 1 hpia.hpcloud.hp.com >nul 2>&1
if %errorLevel% neq 0 (
    echo [WARNING] Unable to reach HP cloud update servers. 
    echo [INFO] Pipeline will rely on local caching structures if available.
)

rem -------------------------------------------------------------------------
rem Execution: Initialize PowerShell Engine Pipeline
rem -------------------------------------------------------------------------
echo [ENGINE] Bootstrapping PowerShell script execution environment...

pushd "%ROOT%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Invoke-HPDeployment.ps1" -SilentFleetDeployment 1
popd

echo [SYSTEM] Deployment script wrapper cycle completed.
echo =========================================================================
pause
exit /b 0