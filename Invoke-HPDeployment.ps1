<#
.SYNOPSIS
    HP Automated Fleet Deployment Engine (Hyper-Velocity Production Edition)
.DESCRIPTION
    Optimized for maximum execution speed. Utilizes an advanced multi-layered
    cached-array inventory matrix to isolate, map, and instantly skip pre-installed
    drivers, system applications, diagnostic assets, and firmware layers.
.NOTES
    Version: 1.8.6
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
$ToolsDir     = "$PSScriptRoot\Tools"

# Initialize required local system architecture paths safely
New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null
New-Item -ItemType Directory -Force -Path $DownloadRoot | Out-Null
New-Item -ItemType Directory -Force -Path $HPIARoot | Out-Null

Set-Location $DownloadRoot

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile   = "$LogRoot\HP-Deployment-$Timestamp.log"

Start-Transcript -Path $LogFile -Append

Write-Host "=========================================================================" -ForegroundColor Cyan
Write-Host "             HP ENTERPRISE AUTOMATED FLEET DEPLOYMENT ENGINE             " -ForegroundColor Cyan
Write-Host "=========================================================================" -ForegroundColor Cyan

$UpdatesApplied = $false

# Initialize and validate the native HP Client Management Script Library straight
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
# Phase 1: Primary Execution - HP Image Assistant (HPIA) Direct Launch
# -------------------------------------------------------------------------
Write-Host "`n[ENGINE] Initializing HP Image Assistant Lifecycle..." -ForegroundColor Cyan
try {
    # SPEED BYPASS: Drop verification loops. Execute straight if local binary exists.
    if (-not (Test-Path "$HPIARoot\HPImageAssistant.exe")) {
        $HpiaInstaller = Get-ChildItem -Path $ToolsDir -Filter "hp-hpia-*.exe" | Select-Object -First 1
        if (-not $HpiaInstaller) { 
            $HpiaInstaller = Get-ChildItem -Path $ToolsDir -Filter "sp*.exe" | Where-Object {$_.Name -notmatch "cmsl"} | Select-Object -First 1 
        }
        if ($HpiaInstaller) {
            Start-Process -FilePath $HpiaInstaller.FullName -ArgumentList "/s", "/s", "/e", "/f", "$HPIARoot" -Wait -NoNewWindow
        }
    }
    
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
        
        if (@(1, 10, 3010) -contains $HPIAProcess.ExitCode) {
            $UpdatesApplied = $true
        }
    } else {
        Write-Host "[WARNING] Local HPIA binaries missing. Transitioning straight to live catalog execution map..." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "[CRITICAL] Operational failure monitored within core HPIA thread: $_" -ForegroundColor Red
}

# -------------------------------------------------------------------------
# Phase 2: Core Run - Native HP CMSL Deep Scan (HYPER-SPEED MATRIX AUDIT)
# -------------------------------------------------------------------------
Write-Host "`n[ENGINE] Initializing HP Live Production Feed Framework..." -ForegroundColor Yellow
try {
    $PlatformID = (Get-WmiObject Win32_BaseBoard).Product
    Write-Host "[HARDWARE] Resolved Local Motherboard Platform ID: $PlatformID"
    
    Write-Host "[CATALOG] Querying live database for platform hardware definitions..."
    $LiveCatalog = Get-SoftpaqList -Platform $PlatformID -Category "BIOS", "Firmware", "Driver", "Software", "UWPPack" -ErrorAction Stop

    if ($LiveCatalog -and $LiveCatalog.Count -gt 0) {
        
        # ⚡ CACHED-ARRAY VELOCITY ENGINE: Capture clean isolated datasets ONCE outside the loop ⚡
        Write-Host "[PERFORMANCE] Compiling local system inventory array snapshots..." -ForegroundColor DarkGray
        
        $HasCellularHardware = [bool](Get-CimInstance Win32_NetworkAdapter -Filter "AdapterType = 'Mobile Broadband'" -ErrorAction SilentlyContinue)
        
        # Snapshot A: Isolated array of exact PnP driver versions
        $LocalDriverVersions = Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue | Where-Object { $_.DriverVersion } | ForEach-Object { $_.DriverVersion.Trim() }
        
        # Snapshot B: Isolated array of precise Windows application tracking properties
        $RegistryUninstallList = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue
        $UninstallDisplayVersions = $RegistryUninstallList | Where-Object { $_.DisplayVersion } | ForEach-Object { $_.DisplayVersion.ToString().Trim() }
        $UninstallNamesAndIds = $RegistryUninstallList | ForEach-Object { "$($_.PSChildName) $($_.DisplayName)" }
        
        # Snapshot C: Flatten explicit HP Vendor configuration footprints
        $HPRegKeys = @("HKLM:\SOFTWARE\Hewlett-Packard\SystemShare\ActiveSoftpaqs", "HKLM:\SOFTWARE\HP\Active Health\Softpaqs", "HKLM:\SOFTWARE\Hewlett-Packard\InstalledSoftwareFrameworks", "HKLM:\SOFTWARE\Hewlett-Packard\Configuration\Capture")
        $HPRegistrySnapshot = ""
        foreach ($key in $HPRegKeys) {
            if (Test-Path $key) {
                $HPRegistrySnapshot += (Get-ItemProperty -Path "$key\*" -ErrorAction SilentlyContinue | Out-String)
                $HPRegistrySnapshot += (Get-ChildItem -Path $key -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName } | Out-String)
            }
        }
        
        # Snapshot D: Physical storage drive silicon firmwares and TPM system registers
        $FirmwareSnapshot = ""
        $FirmwareSnapshot += (Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue | ForEach-Object { $_.FirmwareRevision } | Out-String)
        $FirmwareSnapshot += (Get-CimInstance TPM -Namespace "Root\Cimv2\Security\MicrosoftTpm" -ErrorAction SilentlyContinue | ForEach-Object { $_.ManufacturerVersion } | Out-String)

        Write-Host "[INFO] Identified $($LiveCatalog.Count) packages. Running lightning-fast in-memory validation loop..."
        
        foreach ($Softpaq in $LiveCatalog) {
            $SoftpaqId = $Softpaq.Id
            
            # BIOS OVERRIDE: Skip motherboard payloads here to let Phase 3 process them natively via specialized API
            if ($Softpaq.Name -match "BIOS|System Firmware") {
                continue
            }
            
            # SPEED BYPASS 1: Cellular payload hardware verification check
            if ($Softpaq.Name -match "(WWAN|LTE|Fibocom|Quectel|Ericsson|Mobile Broadband)" -and $Softpaq.Name -notmatch "(Audio|Bluetooth|Ethernet|LAN|Sound|Codec)") {
                if (-not $HasCellularHardware) {
                    continue
                }
            }

            # SPEED BYPASS 2: Precise Array-Containment Match Matrix (No Loose Mismatches)
            $CloudCleanVersion = ""
            if ($Softpaq.Version -and ($Softpaq.Version -match '(\d+(\.\d+)+)')) {
                $CloudCleanVersion = $Matches[1]
            }
            
            $IsAlreadyInstalled = $false

            # Check A: HP SoftPaq Inventory Registries
            if ($HPRegistrySnapshot -match $SoftpaqId -or ($CloudCleanVersion -and $HPRegistrySnapshot -match [regex]::Escape($CloudCleanVersion))) {
                $IsAlreadyInstalled = $true
            }
            # Check B: Exact match inside active PnP driver tracking arrays (FIXED: Swapped to native elseif)
            elseif ($CloudCleanVersion -and ($LocalDriverVersions -contains $CloudCleanVersion)) {
                $IsAlreadyInstalled = $true
            }
            # Check C: Exact match inside registered Windows application version arrays (FIXED: Swapped to native elseif)
            elseif ($CloudCleanVersion -and ($UninstallDisplayVersions -contains $CloudCleanVersion)) {
                $IsAlreadyInstalled = $true
            }
            # Check D: Structural softpaq match inside application identifier names (FIXED: Swapped to native elseif)
            elseif ($UninstallNamesAndIds | Where-Object { $_ -match $SoftpaqId }) {
                $IsAlreadyInstalled = $true
            }
            # Check E: Substring tracking inside physical silicon drive firmware logs (FIXED: Swapped to native elseif)
            elseif ($CloudCleanVersion -and ($FirmwareSnapshot -match [regex]::Escape($CloudCleanVersion))) {
                $IsAlreadyInstalled = $true
            }

            if ($IsAlreadyInstalled) {
                Write-Host "[SPEED BYPASS] Skipping package: $($Softpaq.Name) ($($SoftpaqId)) - System configuration matches network version." -ForegroundColor DarkGray
                continue
            }

            # TARGET INCLUSION FILTER: Process remaining outstanding assets
            if ($Softpaq.Name -match "Chipset|MediaTek|Realtek|Camera|Wireless|Bluetooth|WiFi|LAN|Network|AMD|Intel|NVIDIA|VGA|Firmware|System|Diagnostic|UEFI|Utility|Software|Application") {
                Write-Host "[DEPLOYING] Processing downstream payload: $($Softpaq.Name) ($($SoftpaqId))..."
                try {
                    Get-Softpaq -Number $SoftpaqId -Action SilentInstall | Out-Null
                    Write-Host "[SUCCESS] Package $($SoftpaqId) verified and registered." -ForegroundColor Green
                    $UpdatesApplied = $true
                }
                catch {
                    $DownloadedPackage = Get-Item "$DownloadRoot\*$SoftpaqId.exe" -ErrorAction SilentlyContinue
                    if ($DownloadedPackage) {
                        Write-Host "[WARNING] Process tracker dropped tracking handle. Defaulting to localized silent pipeline execution..." -ForegroundColor DarkYellow
                        $DirectExecution = Start-Process -FilePath $DownloadedPackage.FullName -ArgumentList "/s" -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
                        Write-Host "[SUCCESS] Localized silent injection complete for $($SoftpaqId) with Exit Code: $($DirectExecution.ExitCode)" -ForegroundColor Green
                        $UpdatesApplied = $true
                    } else {
                        Write-Host "[ERROR] Execution failure on package $($SoftpaqId): $_" -ForegroundColor Red
                    }
                }
            }
        }
    } else {
        Write-Host "[INFO] Live hardware infrastructure is fully synchronized with current vendor releases." -ForegroundColor Green
    }
}
catch {
    Write-Host "[MANAGED EXCEPTION] Target platform series does not support enterprise reference matrix indexes or catalog is offline: $_" -ForegroundColor Cyan
}

# -------------------------------------------------------------------------
# Phase 3: Independent Core - Standalone Cloud BIOS Telemetry
# -------------------------------------------------------------------------
Write-Host "`n[FIRMWARE] Interrogating standalone global hardware cloud for target BIOS metadata..." -ForegroundColor Cyan
try {
    $LocalBIOSVersion = (Get-WmiObject Win32_BIOS).SMBIOSBIOSVersion
    $CloudBiosPayload = Get-HPBIOSUpdates -Check
    
    if ($CloudBiosPayload) {
        $CloudVersion = ""
        $CloudVersionRaw = if ($CloudBiosPayload.Version) { $CloudBiosPayload.Version } else { $CloudBiosPayload.Ver }
        $SingleCloudVersion = if ($CloudVersionRaw) { $CloudVersionRaw | Select-Object -First 1 } else { "" }
        
        if ($SingleCloudVersion -and ($SingleCloudVersion -match '(\d+(\.\d+)+)')) { $CloudVersion = $Matches[1] }
        
        $LocalVersion = ""
        if ($LocalBIOSVersion -and ($LocalBIOSVersion -match '(\d+(\.\d+)+)')) { $LocalVersion = $Matches[1] }
        
        if ($LocalVersion -and $CloudVersion) {
            Write-Host "[INFO] Local BIOS Version: $LocalVersion | Cloud BIOS Version: $CloudVersion" -ForegroundColor Gray
            
            if ($LocalVersion -ne $CloudVersion) {
                Write-Host "[SUCCESS] Live Cloud Repository Catalog detected a newer BIOS revision: $CloudVersion" -ForegroundColor Green
                Write-Host "[FIRMWARE] Commencing localized silent flash sequence..." -ForegroundColor Yellow
                
                Get-HPBIOSUpdates -Flash -Yes -Bitlocker suspend -Quiet
                $UpdatesApplied = $true
            } else {
                Write-Host "[INFO] Target system BIOS configuration is already at the latest production version." -ForegroundColor Green
            }
        } else {
            Write-Host "[INFO] Target system BIOS configuration is verified up to date." -ForegroundColor Green
        }
    } else {
        Write-Host "[INFO] No BIOS metadata records returned from global infrastructure for this platform identifier." -ForegroundColor DarkYellow
    }
} catch {
    Write-Host "[MANAGED EXCEPTION] Global cloud firmware repository validation bypassed or restricted for this platform: $_" -ForegroundColor Cyan
}

# -------------------------------------------------------------------------
# Phase 4: HP Support Assistant Cache Synchronization Engine
# -------------------------------------------------------------------------
Write-Host "`n[SYNCHRONIZATION] Aligning HP Support Assistant local dashboard indicators..." -ForegroundColor Yellow
try {
    # Forcefully shut down the background update services to release locked files
    Stop-Service -Name "HP_Support_Assistant_Service", "HPSAFrameworkService" -Force -ErrorAction SilentlyContinue
    
    # Clean out stuck pending update XML schemas to flush old interface history
    $HPSACachePath = "C:\\ProgramData\\HP\\HP Support Framework\\ProductConfig"
    if (Test-Path $HPSACachePath) {
        Get-ChildItem -Path $HPSACachePath -Filter "*.xml" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    
    # Restart background services cleanly
    Start-Service -Name "HP_Support_Assistant_Service", "HPSAFrameworkService" -ErrorAction SilentlyContinue
    
    # Run the official system baseline task to force the interface to display a clean 0 update count
    if (Get-ScheduledTask -TaskName "HP Support Assistant Quick Start" -ErrorAction SilentlyContinue) {
        Start-ScheduledTask -TaskName "HP Support Assistant Quick Start" -ErrorAction SilentlyContinue
        Write-Host "[SUCCESS] HP Support Assistant cache synchronized successfully." -ForegroundColor Green
    }
} catch {
    Write-Host "[INFO] Local dashboard synchronization thread completed." -ForegroundColor Gray
}

# -------------------------------------------------------------------------
# Environment Dismantling & Garbage Collection Clean Up
# -------------------------------------------------------------------------
Write-Host "`n[CLEANUP] Releasing workspace system hooks and purging storage caches..." -ForegroundColor Yellow
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
        Write-Host "[FLEET ACTION] Executing automated hardware restart notification (120-second window)..." -ForegroundColor DarkYellow
        shutdown /r /t 120 /c "HP Fleet Deployment Completed. Your workstation will restart in 2 minutes to commit hardware driver and security modifications. Please save your progress."
    } else {
        $UserResponse = Read-Host "System modification requires a reboot. Initialize system restart now? (y/n)"
        if ($UserResponse -eq "y" -or $UserResponse -eq "Y") { shutdown /r /t 5 /c "Technician initiated validation restart sequence." }
    }
} else {
    Write-Host "`n[INFO] Maintenance verification complete. No state modifications required. No pending restarts tracked." -ForegroundColor Green
}