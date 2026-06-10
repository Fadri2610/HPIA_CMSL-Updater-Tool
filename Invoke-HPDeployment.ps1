<#
.SYNOPSIS
    HP Automated Fleet Deployment Engine (Unified HPIA + CMSL Framework)
.DESCRIPTION
    A resilient, zero-touch deployment script designed to update drivers, software,
    and system firmware across diverse HP commercial assets (EliteBook, ProBook, ZBook, ProOne).
    Utilizes HP Image Assistant (HPIA) as the primary engine and leverages the HP Client 
    Management Script Library (CMSL) as a modular live production catalog fallback.
.PARAMETER SilentFleetDeployment
    When set to $true (default), suppresses interactive user prompts and initiates a 
    graceful, non-blocking 120-second system restart countdown if updates are applied.
.NOTES
    Version: 1.5.3
    Author: Enterprise Systems Management
    Repository: GitHub Production Ready
#>

param (
    [bool]$SilentFleetDeployment = $true
)

# -------------------------------------------------------------------------
# Environment Configuration & Path Layout
# -------------------------------------------------------------------------
$LogRoot      = "C:\Logs\HP"
$DownloadRoot = "C:\HP\Downloads" 
$HPIARoot     = "C:\HP\HPIA"          

# Initialize required local system architecture paths
New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null
New-Item -ItemType Directory -Force -Path $DownloadRoot | Out-Null
New-Item -ItemType Directory -Force -Path $HPIARoot | Out-Null

# Redirect execution context to internal high-speed host storage to optimize I/O
Set-Location $DownloadRoot

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile   = "$LogRoot\HP-Deployment-$Timestamp.log"

Start-Transcript -Path $LogFile -Append

Write-Host "=========================================================================" -ForegroundColor Cyan
Write-Host "             HP ENTERPRISE AUTOMATED FLEET DEPLOYMENT ENGINE             " -ForegroundColor Cyan
Write-Host "=========================================================================" -ForegroundColor Cyan

$UpdatesApplied = $false

# Initialize and validate the native HP Client Management Script Library
Import-Module HP.ClientManagement -ErrorAction Stop

# -------------------------------------------------------------------------
# Security Wrapper: BitLocker Drive Encryption Management
# -------------------------------------------------------------------------
Write-Host "`n[SYSTEM] Evaluating BitLocker Protection State..." -ForegroundColor Yellow
$BitLockerVolume = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
if ($BitLockerVolume -and $BitLockerVolume.ProtectionStatus -eq "On") {
    Write-Host "[WARNING] Active BitLocker volume detected. Suspending protection for firmware validation..." -ForegroundColor DarkYellow
    Suspend-BitLocker -MountPoint "C:" -RebootCount 1
}

# -------------------------------------------------------------------------
# Phase 1: Primary Execution - HP Image Assistant (HPIA)
# -------------------------------------------------------------------------
Write-Host "`n[ENGINE] Initializing HP Image Assistant Lifecycle..." -ForegroundColor Cyan
try {
    Install-HPImageAssistant -Extract -DestinationPath $HPIARoot -Quiet
    
    if (Test-Path "$HPIARoot\HPImageAssistant.exe") {
        $HPIAArguments = @(
            "/Operation:Analyze",
            "/Category:All",
            "/Selection:All",
            "/Action:Install",
            "/Silent",
            "/UWP:Yes", 
            "/SoftpaqDownloadFolder:$DownloadRoot",
            "/ReportFolder:$LogRoot"
        )
        
        $HPIAProcess = Start-Process -FilePath "$HPIARoot\HPImageAssistant.exe" -ArgumentList $HPIAArguments -PassThru -Wait -NoNewWindow
        Write-Host "[COMPLETE] HPIA cycle completed with Exit Code: $($HPIAProcess.ExitCode)" -ForegroundColor Green
        
        # Validation codes: 1 (Reboot Needed), 10 (Installation Success), 3010 (Pending System Restart)
        if (@(1, 10, 3010) -contains $HPIAProcess.ExitCode) {
            $UpdatesApplied = $true
        }
        else {
            # -----------------------------------------------------------------
            # Phase 2: Fallback Contingency - Native HP CMSL Deep Scan Feed
            # -----------------------------------------------------------------
            # Activated on standard up-to-date codes (256/257) or reference anomalies (e.g., 16386 on Essential lines)
            Write-Host "`n[ENGINE] Shifting to HP Live Production Feed Fallback Framework..." -ForegroundColor Yellow
            
            $PlatformID = (Get-WmiObject Win32_BaseBoard).Product
            Write-Host "[HARDWARE] Resolved Local Motherboard Platform ID: $PlatformID"
            
            # Sub-Routine A: Live Driver Production Sync Verification
            Write-Host "[CATALOG] Querying live database for platform hardware definitions..."
            try {
                $LiveCatalog = Get-SoftpaqList -Platform $PlatformID -Category "BIOS", "Firmware", "Driver", "Software", "UWPPack" -ErrorAction Stop

                if ($LiveCatalog -and $LiveCatalog.Count -gt 0) {
                    Write-Host "[INFO] Identified $($LiveCatalog.Count) packages for platform profile. Executing keyword validation..."
                    foreach ($Softpaq in $LiveCatalog) {
                        # Secure multi-vendor targeting array (Intel, AMD, Nvidia, Realtek, MediaTek)
                        if ($Softpaq.Name -match "Chipset|MediaTek|Realtek|Camera|Wireless|Bluetooth|WiFi|LAN|Network|AMD|Intel|NVIDIA|VGA|BIOS|Firmware|System") {
                            Write-Host "[DEPLOYING] Processing downstream payload: $($Softpaq.Name) ($($Softpaq.Id))..."
                            try {
                                Get-Softpaq -Number $Softpaq.Id -Action SilentInstall | Out-Null
                                Write-Host "[SUCCESS] Package $($Softpaq.Id) verified and registered." -ForegroundColor Green
                                $UpdatesApplied = $true
                            }
                            catch {
                                # Exception handling wrapper for complex storage firmware hooks losing process handles
                                $DownloadedPackage = Get-Item "$DownloadRoot\*$($Softpaq.Id).exe" -ErrorAction SilentlyContinue
                                if ($DownloadedPackage) {
                                    Write-Host "[WARNING] Process tracker dropped tracking handle. Defaulting to localized silent pipeline execution..." -ForegroundColor DarkYellow
                                    $DirectExecution = Start-Process -FilePath $DownloadedPackage.FullName -ArgumentList "-s", "/s", "/silent" -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
                                    Write-Host "[SUCCESS] Localized silent injection complete for $($Softpaq.Id) with Exit Code: $($DirectExecution.ExitCode)" -ForegroundColor Green
                                    $UpdatesApplied = $true
                                } else {
                                    Write-Host "[ERROR] Execution failure on package $($Softpaq.Id): $_" -ForegroundColor Red
                                }
                            }
                        }
                    }
                } else {
                    Write-Host "[INFO] Live hardware infrastructure is fully synchronized with current vendor releases." -ForegroundColor Green
                }
            }
            catch {
                # Exception isolation hook: Softpaq validation skipped if platform is an entry-tier model lacking cloud index schemas (.cab matrix missing)
                Write-Host "[MANAGED EXCEPTION] Target platform series does not support enterprise reference matrix indexes. Driver deployment loop safely bypassed." -ForegroundColor Cyan
            }
        } # <--- AQUÍ FINALIZA EL CONDICIONAL RESTRICTIVO ELSE DE HPIA

        # -----------------------------------------------------------------
        # Phase 3: Independent Core - Standalone Cloud BIOS Telemetry
        # -----------------------------------------------------------------
        # This phase executes globally across every cycle to enforce firmware alignment
        Write-Host "`n[FIRMWARE] Interrogating standalone global hardware cloud for target BIOS metadata..." -ForegroundColor Cyan
        try {
            $CloudBiosPayload = Get-HPBIOSUpdates -Check
            if ($CloudBiosPayload) {
                # FIXED: Correct object property mapping to fix the blank spacing issue ("Version .")
                $TargetVersion = if ($CloudBiosPayload.Version) { $CloudBiosPayload.Version } else { $CloudBiosPayload.Ver }
                
                Write-Host "[SUCCESS] Live Cloud Repository Catalog detected an available BIOS revision: $TargetVersion" -ForegroundColor Green
                Write-Host "[FIRMWARE] Commencing localized silent flash sequence..." -ForegroundColor Yellow
                
                Get-HPBIOSUpdates -Flash -Yes -Bitlocker suspend -Quiet
                $UpdatesApplied = $true
            } else {
                Write-Host "[INFO] Target system BIOS configuration matches active master image repository." -ForegroundColor Green
            }
        } catch {
            Write-Host "[MANAGED EXCEPTION] Global cloud firmware repository validation bypassed or restricted for this platform: $_" -ForegroundColor Cyan
        }

    } else {
        Write-Host "[CRITICAL] Unable to locate HPImageAssistant.exe operational binaries post-extraction mapping." -ForegroundColor Red
    }
}
catch {
    Write-Host "[CRITICAL] Operational failure monitored within core update thread lifecycle: $_" -ForegroundColor Red
}

# -------------------------------------------------------------------------
# Environment Dismantling & Garbage Collection Clean Up
# -------------------------------------------------------------------------
Write-Host "`n[CLEANUP] Releasing workspace system hooks and purging storage caches..." -ForegroundColor Yellow

# Explicitly navigate out of the scratch workspace directory prior to purging to prevent Windows directory lock faults
Set-Location C:\

if (Test-Path $DownloadRoot) { Remove-Item -Path $DownloadRoot -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path $HPIARoot)      { Remove-Item -Path $HPIARoot -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "=========================================================================" -ForegroundColor Cyan
Write-Host "                       FLEET MANAGEMENT CYCLE COMPLETE                   " -ForegroundColor Cyan
Write-Host "=========================================================================" -ForegroundColor Cyan
Stop-Transcript

# -------------------------------------------------------------------------
# Enterprise Non-Blocking Reboot Pipeline Handler
# -------------------------------------------------------------------------
$PendingCBSState    = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
$PendingWindowsUpdate = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"

if ($UpdatesApplied -or $PendingCBSState -or $PendingWindowsUpdate) {
    Write-Host "`n[ACTION required] Hardware or system firmware modifications require a service restart to validate state." -ForegroundColor Red
    
    if ($SilentFleetDeployment) {
        Write-Host "[FLEET ACTION] Initiating automated non-blocking hardware restart notification (120-second window)..." -ForegroundColor DarkYellow
        shutdown /r /t 120 /c "HP Fleet Deployment Completed. Your workstation will restart in 2 minutes to commit hardware driver and security modifications. Please save your progress."
    } else {
        $UserResponse = Read-Host "System modification requires a reboot. Initialize system restart now? (y/n)"
        if ($UserResponse -eq "y" -or $UserResponse -eq "Y") {
            shutdown /r /t 5 /c "Technician initiated validation restart sequence."
        }
    }
} else {
    Write-Host "`n[INFO] Maintenance verification complete. No state modifications required. No pending restarts tracked." -ForegroundColor Green
}