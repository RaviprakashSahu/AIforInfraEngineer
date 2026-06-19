[CmdletBinding()]
param(
    [switch]$DryRun,
    [int]$CheckIntervalSeconds = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:LogDirectory = 'C:\Logs'
$script:LogFile = Join-Path -Path $script:LogDirectory -ChildPath 'iis-monitor.log'
$script:StopMonitoring = $false
$script:RollbackExecuted = $false
$script:OriginalPoolStates = @{}
$script:ExitEvent = $null
$script:IISBackend = 'Unknown'
$script:AppCmdPath = Join-Path -Path $env:windir -ChildPath 'System32\inetsrv\appcmd.exe'

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = '{0} [{1}] {2}' -f $timestamp, $Level, $Message
    Add-Content -Path $script:LogFile -Value $entry
}

function Invoke-AppCmd {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    try {
        $output = & $script:AppCmdPath @Arguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            $errorText = ($output | Out-String).Trim()
            throw "appcmd failed: $errorText"
        }

        return $output
    }
    catch {
        throw "appcmd invocation failed: $($_.Exception.Message)"
    }
}

function Initialize-IISBackend {
    $moduleAvailable = Get-Module -ListAvailable -Name WebAdministration
    if ($moduleAvailable) {
        try {
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                Import-Module WebAdministration -UseWindowsPowerShell -ErrorAction Stop
            }
            else {
                Import-Module WebAdministration -ErrorAction Stop
            }

            # Probe provider COM registration before selecting the backend.
            Get-ChildItem -Path IIS:\AppPools -ErrorAction Stop | Select-Object -First 1 | Out-Null
            $script:IISBackend = 'WebAdministration'
            return
        }
        catch {
            $failure = $_.Exception.Message
            if ($failure -match '80040154|Class not registered') {
                if (Test-Path -Path $script:AppCmdPath) {
                    $script:IISBackend = 'AppCmd'
                    return
                }

                throw "IIS provider COM registration is broken and appcmd fallback is unavailable. Install/repair Web-Scripting-Tools. Inner error: $failure"
            }

            if (Test-Path -Path $script:AppCmdPath) {
                $script:IISBackend = 'AppCmd'
                return
            }

            throw "Unable to initialize IIS backend. WebAdministration failed and appcmd fallback is unavailable. Inner error: $failure"
        }
    }

    if (Test-Path -Path $script:AppCmdPath) {
        $script:IISBackend = 'AppCmd'
        return
    }

    throw 'No IIS automation backend is available. Install IIS Management Scripts and Tools or ensure appcmd.exe exists at %windir%\System32\inetsrv\appcmd.exe.'
}

function Initialize-LogPath {
    if (-not (Test-Path -Path $script:LogDirectory)) {
        New-Item -Path $script:LogDirectory -ItemType Directory -Force | Out-Null
    }

    if (-not (Test-Path -Path $script:LogFile)) {
        New-Item -Path $script:LogFile -ItemType File -Force | Out-Null
    }
}

function Get-AppPoolStateSnapshot {
    if ($script:IISBackend -eq 'WebAdministration') {
        try {
            $poolNames = Get-ChildItem -Path IIS:\AppPools | Select-Object -ExpandProperty Name
        }
        catch {
            Write-Log -Message ("Failed to enumerate IIS application pools: {0}" -f $_.Exception.Message) -Level 'ERROR'
            throw
        }

        $states = foreach ($poolName in $poolNames) {
            try {
                $poolState = Get-WebAppPoolState -Name $poolName
                [pscustomobject]@{
                    Name  = $poolName
                    State = [string]$poolState.Value
                }
            }
            catch {
                Write-Log -Message ("Failed to read state for application pool '{0}': {1}" -f $poolName, $_.Exception.Message) -Level 'ERROR'
                throw
            }
        }

        return $states
    }

    try {
        $poolNames = @((Invoke-AppCmd -Arguments @('list', 'apppool', '/text:name')) | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ })
    }
    catch {
        Write-Log -Message ("Failed to enumerate IIS application pools via appcmd: {0}" -f $_.Exception.Message) -Level 'ERROR'
        throw
    }

    $states = foreach ($poolName in $poolNames) {
        try {
            $poolStateText = (Invoke-AppCmd -Arguments @('list', 'apppool', "/apppool.name:$poolName", '/text:state') | Select-Object -First 1).ToString().Trim()
            [pscustomobject]@{
                Name  = $poolName
                State = $poolStateText
            }
        }
        catch {
            Write-Log -Message ("Failed to read state for application pool '{0}' via appcmd: {1}" -f $poolName, $_.Exception.Message) -Level 'ERROR'
            throw
        }
    }

    return $states
}

function Save-OriginalPoolState {
    $poolStates = Get-AppPoolStateSnapshot

    foreach ($pool in $poolStates) {
        if (-not $script:OriginalPoolStates.ContainsKey($pool.Name)) {
            $script:OriginalPoolStates[$pool.Name] = $pool.State
            Write-Log -Message ("Captured original state for pool '{0}': {1}" -f $pool.Name, $pool.State)
        }
    }
}

function Get-RecentEventLogError {
    $startTime = (Get-Date).AddMinutes(-10)
    Write-Log -Message ("Capturing Windows Event Log errors since {0}" -f $startTime.ToString('yyyy-MM-dd HH:mm:ss'))

    try {
        $events = Get-WinEvent -FilterHashtable @{
            LogName   = @('Application', 'System')
            StartTime = $startTime
            Level     = 2
        }
    }
    catch {
        Write-Log -Message ("Failed to query Windows Event Log: {0}" -f $_.Exception.Message) -Level 'ERROR'
        throw
    }

    if (-not $events) {
        Write-Log -Message 'No Application/System error events found in the last 10 minutes'
        return
    }

    foreach ($logEvent in $events) {
        $message = $logEvent.Message
        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = '<no message>'
        }

        $singleLineMessage = ($message -replace '\r?\n', ' ').Trim()
        Write-Log -Message (
            "EventLog Error | Time={0} | Log={1} | Provider={2} | Id={3} | Message={4}" -f
            $logEvent.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'),
            $logEvent.LogName,
            $logEvent.ProviderName,
            $logEvent.Id,
            $singleLineMessage
        ) -Level 'WARN'
    }
}

function Restart-AppPoolIfNeeded {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [string]$PoolName
    )

    if ($script:IISBackend -eq 'WebAdministration') {
        try {
            $currentState = [string](Get-WebAppPoolState -Name $PoolName).Value
        }
        catch {
            Write-Log -Message ("Failed to confirm state for application pool '{0}' before restart: {1}" -f $PoolName, $_.Exception.Message) -Level 'ERROR'
            throw
        }
    }
    else {
        try {
            $currentState = (Invoke-AppCmd -Arguments @('list', 'apppool', "/apppool.name:$PoolName", '/text:state') | Select-Object -First 1).ToString().Trim()
        }
        catch {
            Write-Log -Message ("Failed to confirm state for application pool '{0}' via appcmd before restart: {1}" -f $PoolName, $_.Exception.Message) -Level 'ERROR'
            throw
        }
    }

    if ($currentState -eq 'Started') {
        Write-Log -Message ("Application pool '{0}' is already running; no restart needed" -f $PoolName)
        return
    }

    if ($DryRun) {
        Write-Log -Message ("DRY-RUN: Would restart application pool '{0}' from state '{1}'" -f $PoolName, $currentState)
        return
    }

    if ($PSCmdlet.ShouldProcess($PoolName, 'Restart IIS application pool')) {
        try {
            if ($script:IISBackend -eq 'WebAdministration') {
                Restart-WebAppPool -Name $PoolName
            }
            else {
                Invoke-AppCmd -Arguments @('recycle', 'apppool', "/apppool.name:$PoolName") | Out-Null
            }
            Write-Log -Message ("Restarted application pool '{0}'" -f $PoolName)
        }
        catch {
            Write-Log -Message ("Failed to restart application pool '{0}': {1}" -f $PoolName, $_.Exception.Message) -Level 'ERROR'
            throw
        }
    }
    else {
        Write-Log -Message ("ShouldProcess declined restart for application pool '{0}'" -f $PoolName) -Level 'WARN'
    }
}

function Invoke-MonitorRollback {
    param(
        [string]$Reason = 'Rollback requested'
    )

    if ($script:RollbackExecuted) {
        return
    }

    $script:RollbackExecuted = $true
    $script:StopMonitoring = $true
    Write-Log -Message ("Rollback initiated: {0}" -f $Reason) -Level 'WARN'

    foreach ($poolName in $script:OriginalPoolStates.Keys) {
        $desiredState = $script:OriginalPoolStates[$poolName]

        try {
            if ($script:IISBackend -eq 'WebAdministration') {
                $currentState = [string](Get-WebAppPoolState -Name $poolName).Value
            }
            else {
                $currentState = (Invoke-AppCmd -Arguments @('list', 'apppool', "/apppool.name:$poolName", '/text:state') | Select-Object -First 1).ToString().Trim()
            }
        }
        catch {
            Write-Log -Message ("Failed to read current state for application pool '{0}' during rollback: {1}" -f $poolName, $_.Exception.Message) -Level 'ERROR'
            continue
        }

        if ($currentState -eq $desiredState) {
            Write-Log -Message ("Rollback skipped for application pool '{0}'; already in original state '{1}'" -f $poolName, $desiredState)
            continue
        }

        if ($DryRun) {
            Write-Log -Message ("DRY-RUN: Would restore application pool '{0}' from '{1}' to '{2}'" -f $poolName, $currentState, $desiredState)
            continue
        }

        try {
            switch ($desiredState) {
                'Started' {
                    if ($script:IISBackend -eq 'WebAdministration') {
                        Start-WebAppPool -Name $poolName
                    }
                    else {
                        Invoke-AppCmd -Arguments @('start', 'apppool', "/apppool.name:$poolName") | Out-Null
                    }
                }
                'Stopped' {
                    if ($script:IISBackend -eq 'WebAdministration') {
                        Stop-WebAppPool -Name $poolName
                    }
                    else {
                        Invoke-AppCmd -Arguments @('stop', 'apppool', "/apppool.name:$poolName") | Out-Null
                    }
                }
                default {
                    Write-Log -Message ("Rollback does not manage application pool '{0}' original state '{1}'; leaving current state '{2}'" -f $poolName, $desiredState, $currentState) -Level 'WARN'
                    continue
                }
            }

            Write-Log -Message ("Restored application pool '{0}' to original state '{1}'" -f $poolName, $desiredState)
        }
        catch {
            Write-Log -Message ("Failed to restore application pool '{0}' to '{1}': {2}" -f $poolName, $desiredState, $_.Exception.Message) -Level 'ERROR'
        }
    }
}

function Register-CleanExitHandler {
    $script:ExitEvent = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        $script:StopMonitoring = $true
        if (-not $script:RollbackExecuted) {
            Invoke-MonitorRollback -Reason 'PowerShell exiting'
        }
    }
}

Initialize-LogPath
Initialize-IISBackend
Write-Log -Message ("Starting IIS application pool monitor. Interval={0}s DryRun={1} Backend={2}" -f $CheckIntervalSeconds, $DryRun.IsPresent, $script:IISBackend)

Save-OriginalPoolState
Register-CleanExitHandler

try {
    while (-not $script:StopMonitoring) {
        $poolStates = Get-AppPoolStateSnapshot
        $stoppedPools = @($poolStates | Where-Object { $_.State -eq 'Stopped' })

        if ($stoppedPools.Count -gt 0) {
            $poolList = ($stoppedPools.Name -join ', ')
            Write-Log -Message ("Detected stopped application pool(s): {0}" -f $poolList) -Level 'WARN'
            Get-RecentEventLogError

            foreach ($pool in $stoppedPools) {
                Restart-AppPoolIfNeeded -PoolName $pool.Name
            }
        }
        else {
            Write-Log -Message 'All IIS application pools are running'
        }

        if (-not $script:StopMonitoring) {
            Start-Sleep -Seconds $CheckIntervalSeconds
        }
    }
}
catch [System.Management.Automation.PipelineStoppedException] {
    Write-Log -Message 'Monitoring interrupted by pipeline stop request' -Level 'WARN'
    Invoke-MonitorRollback -Reason 'Pipeline stop request'
}
catch {
    Write-Log -Message ("Unhandled monitoring error: {0}" -f $_.Exception.Message) -Level 'ERROR'
    Invoke-MonitorRollback -Reason 'Unhandled monitoring error'
    throw
}
finally {
    Invoke-MonitorRollback -Reason 'Monitor loop exited'

    if ($null -ne $script:ExitEvent) {
        Unregister-Event -SourceIdentifier PowerShell.Exiting -ErrorAction SilentlyContinue
        Remove-Job -Id $script:ExitEvent.Id -Force -ErrorAction SilentlyContinue
    }

    Write-Log -Message 'IIS application pool monitor stopped'
}