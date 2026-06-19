$cpu     = (Get-CimInstance Win32_Processor |
            Measure-Object -Property LoadPercentage -Average).Average
$os      = Get-CimInstance Win32_OperatingSystem
$freeMB  = [math]::Round($os.FreePhysicalMemory / 1KB, 1)
$totalMB = [math]::Round($os.TotalVisibleMemorySize / 1KB, 1)
$disk    = Get-PSDrive C
$freeGB  = [math]::Round($disk.Free / 1GB, 1)

Write-Host ""
Write-Host "=== PRE-FAULT BASELINE ==="
Write-Host "Timestamp : $(Get-Date -Format yyyy-MM-ddTHH:mm:ssZ)"
Write-Host "CPU       : $cpu%"
Write-Host "Free RAM  : $freeMB MB of $totalMB MB"
Write-Host "Disk C:   : $freeGB GB free"
Write-Host ""
