# ============================================================
# FinBridge — fault_inject.ps1
# Purpose: Simulate CPU + memory exhaustion on the compute tower
# Run as Administrator on the TARGET VM via RDP
# ============================================================
param(
    [ValidateSet("CPU","Memory","Both")]
    [string]$Mode            = "Both",
    [int]   $DurationSeconds = 300,
    [int]   $MemoryMB        = 1800,
    [string]$LogPath         = "C:\FinBridge\Logs\fault_inject.log"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -- Logging helper --------------------------------------------
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts   = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    $line = "[$ts] [$Level] $Message"
    Write-Host $line
    $dir = Split-Path $LogPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

# -- Safety Gate: restore_vm.ps1 must exist --------------------
function Assert-RestoreScriptExists {
    $paths = @(
        (Join-Path $PSScriptRoot "restore_vm.ps1"),
        "C:\FinBridge\Scripts\restore_vm.ps1"
    )
    $found = $paths | Where-Object { Test-Path $_ }
    if (-not $found) {
        Write-Log "SAFETY GATE FAILED: restore_vm.ps1 not found." "ERROR"
        Write-Log "Copy restore_vm.ps1 to the same folder and test it first." "ERROR"
        throw "Aborted: restore_vm.ps1 must exist and have been tested before fault injection."
    }
    Write-Log "Safety gate passed: restore_vm.ps1 confirmed present."
}

# -- CPU stress (background PS jobs) --------------------------
$cpuJobs = @()
function Start-CPUFault {
    $threads = [Environment]::ProcessorCount
    Write-Log "Starting CPU fault: $threads threads for ${DurationSeconds}s"
    for ($i = 0; $i -lt $threads; $i++) {
        $job = Start-Job -ScriptBlock {
            param($dur)
            $end = (Get-Date).AddSeconds($dur)
            while ((Get-Date) -lt $end) {
                [void]([math]::Sqrt([math]::PI))
            }
        } -ArgumentList $DurationSeconds
        $script:cpuJobs += $job
        Write-Log "  CPU stress thread $($i+1)/$threads started (Job $($job.Id))"
    }
}

# -- Memory stress ---------------------------------------------
$memBuffer = $null
function Start-MemoryFault {
    Write-Log "Starting Memory fault: allocating ${MemoryMB} MB"
    try {
        $bytes = $MemoryMB * 1MB
        $script:memBuffer = New-Object byte[] $bytes
        for ($i = 0; $i -lt $bytes; $i += 4096) {
            $script:memBuffer[$i] = 0xFF   # page-touch to commit physical RAM
        }
        Write-Log "  Memory allocated: ${MemoryMB} MB committed and page-touched."
    } catch {
        Write-Log "Memory allocation warning: $_" "WARN"
    }
}

# -- Monitor during fault --------------------------------------
function Monitor-Fault {
    Write-Log "=== FAULT ACTIVE — sampling every 15s for ${DurationSeconds}s ==="
    $end    = (Get-Date).AddSeconds($DurationSeconds)
    $sample = 0
    while ((Get-Date) -lt $end) {
        Start-Sleep -Seconds 15
        $sample++
        $cpu    = (Get-CimInstance Win32_Processor |
                   Measure-Object -Property LoadPercentage -Average).Average
        $freeMB = [math]::Round(
                   (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1KB, 1)
        Write-Log "  [Sample $sample] CPU: $cpu% | Free RAM: $freeMB MB"
    }
}

# -- Cleanup ---------------------------------------------------
function Stop-Fault {
    Write-Log "=== STOPPING FAULT — releasing resources ==="
    foreach ($job in $script:cpuJobs) {
        Stop-Job  -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        Write-Log "  CPU job $($job.Id) stopped."
    }
    $script:cpuJobs = @()
    if ($null -ne $script:memBuffer) {
        $script:memBuffer = $null
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        Write-Log "  Memory buffer released and GC collected."
    }
    Write-Log "Fault stopped. Run restore_vm.ps1 if metrics have not recovered."
}

# ====================================================================
# MAIN
# ====================================================================
Write-Log "======================================================"
Write-Log "FinBridge Fault Injection — STARTING"
Write-Log "Mode: $Mode | Duration: ${DurationSeconds}s | Host: $env:COMPUTERNAME"
Write-Log "======================================================"

Assert-RestoreScriptExists

try {
    if ($Mode -in @("CPU","Both"))    { Start-CPUFault }
    if ($Mode -in @("Memory","Both")) { Start-MemoryFault }
    Monitor-Fault
} finally {
    Stop-Fault
    Write-Log "Evidence log: $LogPath"
}