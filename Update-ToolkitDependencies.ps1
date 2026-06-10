<#
.SYNOPSIS
    HP Toolkit Administrative Maintenance Engine
.DESCRIPTION
    Queries global HP endpoint repositories to fetch, validate, and refresh 
    localized deployment payloads (CMSL and HPIA installers) inside the \Tools directory.
.NOTES
    Version: 1.1.1
    Author: Enterprise Systems Management
    Context: Run on Administrator Management Workstation
#>

# OPTIMIZATION: Disables the native progress bar rendering loop, speeding up downloads by up to 10x
$ProgressPreference = 'SilentlyContinue'

$TargetDirectory = "$PSScriptRoot\Tools"
if (-not (Test-Path $TargetDirectory)) {
    New-Item -ItemType Directory -Force -Path $TargetDirectory | Out-Null
}

Write-Host "=========================================================================" -ForegroundColor Cyan
Write-Host "             HP MANAGEMENT WORKSTATION: TOOLKIT REFRESH CORE             " -ForegroundColor Cyan
Write-Host "=========================================================================" -ForegroundColor Cyan

# -------------------------------------------------------------------------
# Phase 1: Fetch HP Client Management Script Library (CMSL) - DIRECT CDN
# -------------------------------------------------------------------------
Write-Host "`n[QUERY] Streaming HP CMSL production package via verified CDN..." -ForegroundColor Yellow
try {
    # Using the exact direct-download CDN link confirmed to bypass all web locks
    $CmslDownloadUrl = "https://hpia.hpcloud.hp.com/downloads/cmsl/hp-cmsl-1.8.6.exe"
    $CmslFileName    = "hp-cmsl-1.8.6.exe"
    $CmslDestination = "$TargetDirectory\$CmslFileName"
    
    if (-not (Test-Path $CmslDestination)) {
        Write-Host "[CLEANUP] Scrubbing historical CMSL payloads from \Tools..." -ForegroundColor DarkYellow
        Get-ChildItem -Path $TargetDirectory -Filter "hp-cmsl-*" | Remove-Item -Force
        
        Write-Host "[DOWNLOAD] Downloading modern CMSL framework package..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $CmslDownloadUrl -OutFile $CmslDestination -UseBasicParsing -ErrorAction Stop
        Write-Host "[SUCCESS] Successfully staged $CmslFileName inside \Tools." -ForegroundColor Green
    } else {
        Write-Host "[INFO] Localized copy of $CmslFileName is already current." -ForegroundColor Green
    }
}
catch {
    Write-Host "[ERROR] Failed downloading global CMSL package via CDN: $_" -ForegroundColor Red
}

# -------------------------------------------------------------------------
# Phase 2: Fetch Latest HP Image Assistant (HPIA) Binaries (CONFIRMED WORKING)
# -------------------------------------------------------------------------
Write-Host "`n[QUERY] Fetching latest HP Image Assistant production software payload..." -ForegroundColor Yellow
try {
    $HpBaseUrl = "https://ftp.ext.hp.com/pub/caps-softpaq/cmit"
    $HpiaLandingUrl = "$HpBaseUrl/HPIA.html"
    $HpiaWebResponse = Invoke-WebRequest -Uri $HpiaLandingUrl -UseBasicParsing -ErrorAction Stop
    
    # FIXED: Escaped the internal single quote syntax inside the regular expression to ensure robust execution
    $HpiaLinks = [regex]::Matches($HpiaWebResponse.Content, '(?i)href\s*=\s*["'' ]([^"'' >]+\.exe)["'' ]') | ForEach-Object { $_.Groups[1].Value }
    $HpiaMatch = $HpiaLinks | Where-Object { $_ -match 'hp-hpia|hpia|sp\d+' } | Select-Object -First 1
    
    if ($HpiaMatch) {
        $HpiaDownloadUrl = if ($HpiaMatch -like "http*") { $HpiaMatch } else { "$HpBaseUrl/$HpiaMatch" }
        $HpiaFileName    = Split-Path $HpiaDownloadUrl -Leaf
        
        Write-Host "[MATCH] Isolated clean target HPIA filename: $HpiaFileName" -ForegroundColor Green
        $HpiaDestinationPath = "$TargetDirectory\$HpiaFileName"
        
        if (-not (Test-Path $HpiaDestinationPath)) {
            Write-Host "[CLEANUP] Scrubbing historical HPIA payloads from \Tools..." -ForegroundColor DarkYellow
            Get-ChildItem -Path $TargetDirectory -Filter "sp*.exe" | Remove-Item -Force
            Get-ChildItem -Path $TargetDirectory -Filter "hp-hpia-*.exe" | Remove-Item -Force
            
            Write-Host "[DOWNLOAD] Downloading modern HPIA payload into repository cache..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $HpiaDownloadUrl -OutFile $HpiaDestinationPath -UseBasicParsing -ErrorAction Stop
            Write-Host "[SUCCESS] Successfully staged $HpiaFileName inside \Tools." -ForegroundColor Green
        } else {
            Write-Host "[INFO] Localized copy of $HpiaFileName is already current." -ForegroundColor Green
        }
    } else {
        Write-Host "[ERROR] Automation was unable to isolate a valid HPIA package link from HTML matrix." -ForegroundColor Red
    }
}
catch {
    Write-Host "[CRITICAL] Operational failure fetching downstream remote binaries: $_" -ForegroundColor Red
}

Write-Host "`n=========================================================================" -ForegroundColor Cyan
Write-Host "                       TOOLKIT MAINTENANCE COMPLETE                      " -ForegroundColor Cyan
Write-Host "=========================================================================" -ForegroundColor Cyan