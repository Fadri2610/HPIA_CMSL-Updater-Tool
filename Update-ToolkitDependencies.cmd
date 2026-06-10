@echo off
rem =========================================================================
rem HP Enterprise Fleet Deployment - Workstation Maintenance Launcher
rem v1.0.0 - Elevated Environment Bootstrap for Dependency Sync
rem =========================================================================
setlocal enabledelayedexpansion

title HP Fleet Workstation Tool - Maintainer

echo =========================================================================
echo             HP DEPLOYMENT REPOSITORY: WORKSTATION REFRESH ENGINE        
echo =========================================================================

set "ROOT=%~dp0"

rem -------------------------------------------------------------------------
rem Security Validation: Verify Administrative Context
rem -------------------------------------------------------------------------
echo [SYSTEM] Validating security tokens...
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [CRITICAL] Elevated administrative privileges are required.
    echo [ACTION] Please relaunch this maintenance tool using 'Run as Administrator'.
    echo =========================================================================
    pause
    exit /b 1
)

rem -------------------------------------------------------------------------
rem Execution: Launch Workstation Maintenance Thread
rem -------------------------------------------------------------------------
echo [ENGINE] Initializing secure download pipelines...

pushd "%ROOT%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%ROOT%Update-ToolkitDependencies.ps1'"
popd

echo.
echo [SYSTEM] Toolkit maintenance execution thread completed.
echo =========================================================================
pause
exit /b 0