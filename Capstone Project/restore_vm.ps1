# ============================================================
# FinBridge — restore_vm.ps1
# Purpose: Stop fault processes, verify VM health
# Run as Administrator on the TARGET VM via RDP
# ============================================================
param(
    [switch]$Verify               = $false,
    [int]   $RecoveryWaitSeconds  = 60,
    [string]$LogPath              = "C:\FinBridge\Logs\restore.log",
    [int]   $CPUThresholdPct      = 30,
    [int]   $MemFreeMinMB         = 500
)

$ErrorActionPreference = "Continue"   # resilient — do not abort on one failure

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

# -- Kill all PS background jobs -------------------------------
function Stop-StressProcesses {
    Write-Log "=== STEP 1: Terminating stress processes ==="
    $jobs = Get-Job -ErrorAction SilentlyContinue
    if ($jobs) {
        foreach ($job in $jobs) {
            Stop-Job  -Job $job -ErrorAction SilentlyContinue
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            Write-Log "  Removed PS job: $($job.Name) (was $($job.State))"
        }
    } else {
        Write-Log "  No PowerShell background jobs found."
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    [GC]::Collect()
    Write-Log "  .NET GC completed."
}

# -- Verify critical Windows services --------------------------
function Restore-CriticalServices {
    Write-Log "=== STEP 2: Verifying critical Windows services ==="
    $services = @(
        @{ Name="W32Time";  Display="Windows Time" },
        @{ Name="Winmgmt";  Display="WMI" },
        @{ Name="EventLog"; Display="Windows Event Log" },
        @{ Name="Schedule"; Display="Task Scheduler" },
        @{ Name="RpcSs";    Display="RPC" }
    )
    foreach ($svc in $services) {
        try {
            $s = Get-Service -Name $svc.Name -ErrorAction Stop
            if ($s.Status -ne "Running") {
                Start-Service -Name $svc.Name -ErrorAction Stop
                Write-Log "  $($svc.Display): STARTED (was $($s.Status))" "WARN"
            } else {
                Write-Log "  $($svc.Display): Running OK"
            }
        } catch {
            Write-Log "  $($svc.Display): Error - $_" "ERROR"
        }
    }
}

# -- Wait for OS to stabilise ----------------------------------
function Wait-ForRecovery {
    Write-Log "=== STEP 3: Waiting ${RecoveryWaitSeconds}s for stabilisation ==="
    $end = (Get-Date).AddSeconds($RecoveryWaitSeconds)
    while ((Get-Date) -lt $end) {
        Start-Sleep -Seconds 10
        $cpu    = (Get-CimInstance Win32_Processor |
                   Measure-Object -Property LoadPercentage -Average).Average
        $freeMB = [math]::Round(
                   (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1KB, 1)
        $rem    = [int](($end - (Get-Date)).TotalSeconds)
        Write-Log "  Stabilising: CPU $cpu% | Free RAM $freeMB MB | ${rem}s remaining"
        if ($cpu -le $CPUThresholdPct -and $freeMB -ge $MemFreeMinMB) {
            Write-Log "  Early recovery — skipping remaining wait."
            break
        }
    }
}

# -- Health check ----------------------------------------------
function Invoke-HealthCheck {
    Write-Log "=== STEP 4: Health verification ==="
    $pass = $true

    # CPU
    $cpu = (Get-CimInstance Win32_Processor |
            Measure-Object -Property LoadPercentage -Average).Average
    if ($cpu -le $CPUThresholdPct) {
        Write-Log "  [PASS] CPU: $cpu% (threshold <= $CPUThresholdPct%)"
    } else {
        Write-Log "  [FAIL] CPU: $cpu% — still above $CPUThresholdPct%" "WARN"
        $pass = $false
    }

    # Memory
    $os      = Get-CimInstance Win32_OperatingSystem
    $freeMB  = [math]::Round($os.FreePhysicalMemory / 1KB, 1)
    $totalMB = [math]::Round($os.TotalVisibleMemorySize / 1KB, 1)
    if ($freeMB -ge $MemFreeMinMB) {
        Write-Log "  [PASS] Memory: $freeMB MB free of $totalMB MB"
    } else {
        Write-Log "  [FAIL] Memory: only $freeMB MB free (need >= $MemFreeMinMB MB)" "WARN"
        $pass = $false
    }

    # Disk
    $disk   = Get-PSDrive C
    $freeGB = [math]::Round($disk.Free / 1GB, 1)
    if ($freeGB -ge 10) {
        Write-Log "  [PASS] Disk C: $freeGB GB free"
    } else {
        Write-Log "  [WARN] Disk C: only $freeGB GB free" "WARN"
    }

    # Azure IMDS network test
    try {
        $null = Invoke-RestMethod `
            -Uri "http://169.254.169.254/metadata/instance?api-version=2021-02-01" `
            -Headers @{ Metadata="true" } -TimeoutSec 5
        Write-Log "  [PASS] Azure IMDS reachable — network stack healthy"
    } catch {
        Write-Log "  [WARN] Azure IMDS not reachable: $_" "WARN"
    }

    # RDP service
    $rdp = Get-Service -Name "TermService" -ErrorAction SilentlyContinue
    if ($rdp.Status -eq "Running") {
        Write-Log "  [PASS] RDP (TermService): Running"
    } else {
        Write-Log "  [FAIL] RDP (TermService): $($rdp.Status)" "ERROR"
        $pass = $false
    }

    return $pass
}

# -- Recent error events ---------------------------------------
function Export-RecentErrors {
    Write-Log "=== STEP 5: Recent system errors (last 30 min) ==="
    $since  = (Get-Date).AddMinutes(-30)
    $events = Get-WinEvent -FilterHashtable @{
        LogName   = "System","Application"
        Level     = 1,2
        StartTime = $since
    } -MaxEvents 10 -ErrorAction SilentlyContinue
    if ($events) {
        foreach ($ev in $events) {
            $msg = $ev.Message.Substring(0, [Math]::Min(100, $ev.Message.Length))
            Write-Log "  [$($ev.TimeCreated.ToString("HH:mm:ss"))] $($ev.LevelDisplayName) — $msg"
        }
    } else {
        Write-Log "  No critical/error events in last 30 minutes."
    }
}

# ====================================================================
# MAIN
# ====================================================================
Write-Log "======================================================"
Write-Log "FinBridge Restore — STARTING"
Write-Log "Mode: $(if ($Verify) { "Verify-only" } else { "Full restore" })"
Write-Log "Host: $env:COMPUTERNAME"
Write-Log "======================================================"

if (-not $Verify) {
    Stop-StressProcesses
    Restore-CriticalServices
    Wait-ForRecovery
}

$passed = Invoke-HealthCheck
Export-RecentErrors

Write-Log "======================================================"
if ($passed) {
    Write-Log "RESTORE VERIFIED — all health checks passed."
    exit 0
} else {
    Write-Log "RESTORE INCOMPLETE — one or more checks failed. Check log: $LogPath" "ERROR"
    exit 1
}
