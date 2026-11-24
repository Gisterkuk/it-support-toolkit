<#
.SYNOPSIS
    Collects a quick health report of a Windows PC to attach to a support ticket.

.DESCRIPTION
    Gathers the basics a technician asks for first: OS and build, uptime, CPU, memory,
    disk space, network configuration, pending reboot, latest updates and the processes
    using the most memory. Saves everything in one text file named after the computer.

    Read-only: it does not change anything on the machine. Runs without admin rights.

.PARAMETER OutputPath
    Folder where the report is saved. Default: the current user's Desktop.

.PARAMETER LowDiskPercent
    A disk with less free space than this percentage is flagged. Default: 15.

.EXAMPLE
    .\Get-SystemReport.ps1

.EXAMPLE
    .\Get-SystemReport.ps1 -OutputPath C:\Temp -LowDiskPercent 20
#>
[CmdletBinding()]
param(
    [string]$OutputPath = [Environment]::GetFolderPath('Desktop'),

    [ValidateRange(1, 99)]
    [int]$LowDiskPercent = 15
)

$ErrorActionPreference = 'Stop'

function Test-PendingReboot {
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    foreach ($key in $keys) {
        if (Test-Path $key) { return $true }
    }
    $session = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -ErrorAction SilentlyContinue
    return [bool]($session -and $session.PendingFileRenameOperations)
}

$os     = Get-CimInstance Win32_OperatingSystem
$system = Get-CimInstance Win32_ComputerSystem
$cpu    = Get-CimInstance Win32_Processor | Select-Object -First 1
$bios   = Get-CimInstance Win32_BIOS
$uptime = (Get-Date) - $os.LastBootUpTime

# Win32_OperatingSystem reports memory in KB.
$memTotalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
$memFreeGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
$memUsedPct = [math]::Round(100 - ($os.FreePhysicalMemory / $os.TotalVisibleMemorySize * 100))

$report = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

$report.Add("System report - $($env:COMPUTERNAME) - $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
$report.Add('=' * 60)

$report.Add('')
$report.Add('[Machine]')
$report.Add("User          : $($env:USERDOMAIN)\$($env:USERNAME)")
$report.Add("Domain/Group  : $($system.Domain)")
$report.Add("Model         : $($system.Manufacturer) $($system.Model)")
$report.Add("Serial number : $($bios.SerialNumber)")
$report.Add("OS            : $($os.Caption) $($os.Version) (build $($os.BuildNumber))")
$report.Add("Uptime        : $($uptime.Days) d $($uptime.Hours) h $($uptime.Minutes) min (last boot $($os.LastBootUpTime))")
$report.Add("CPU           : $($cpu.Name.Trim()) - load $($cpu.LoadPercentage)%")
$report.Add("Memory        : $memUsedPct% used ($memFreeGB GB free of $memTotalGB GB)")

if ($uptime.TotalDays -gt 14) { $warnings.Add("No restart in $([int]$uptime.TotalDays) days.") }
if ($memUsedPct -ge 90)        { $warnings.Add("Memory usage is $memUsedPct%.") }
if (Test-PendingReboot)        { $warnings.Add('Windows is waiting for a restart to finish updates.') }

$report.Add('')
$report.Add('[Disks]')
foreach ($disk in Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3') {
    if (-not $disk.Size) { continue }
    $sizeGB  = [math]::Round($disk.Size / 1GB, 1)
    $freeGB  = [math]::Round($disk.FreeSpace / 1GB, 1)
    $freePct = [math]::Round($disk.FreeSpace / $disk.Size * 100)
    $report.Add(('{0}  {1,7} GB free of {2,7} GB  ({3}% free)' -f $disk.DeviceID, $freeGB, $sizeGB, $freePct))
    if ($freePct -lt $LowDiskPercent) { $warnings.Add("Disk $($disk.DeviceID) has only $freePct% free.") }
}

$report.Add('')
$report.Add('[Network]')
foreach ($nic in Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True') {
    $report.Add("Adapter : $($nic.Description)")
    $report.Add("  IP      : $($nic.IPAddress -join ', ')")
    $report.Add("  Gateway : $($nic.DefaultIPGateway -join ', ')")
    $report.Add("  DNS     : $($nic.DNSServerSearchOrder -join ', ')")
    $report.Add("  DHCP    : $($nic.DHCPEnabled)   MAC: $($nic.MACAddress)")
}

$report.Add('')
$report.Add('[Latest updates]')
Get-CimInstance Win32_QuickFixEngineering |
    Sort-Object InstalledOn -Descending |
    Select-Object -First 5 |
    ForEach-Object { $report.Add(('{0}  {1}  {2}' -f $_.HotFixID, $_.InstalledOn, $_.Description)) }

$report.Add('')
$report.Add('[Top 10 processes by memory]')
Get-Process |
    Sort-Object WorkingSet64 -Descending |
    Select-Object -First 10 |
    ForEach-Object { $report.Add(('{0,-30} {1,8} MB' -f $_.ProcessName, [math]::Round($_.WorkingSet64 / 1MB))) }

$report.Add('')
$report.Add('[Warnings]')
if ($warnings.Count -eq 0) {
    $report.Add('None.')
} else {
    foreach ($w in $warnings) { $report.Add("- $w") }
}

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}
$file = Join-Path $OutputPath ('{0}-report-{1}.txt' -f $env:COMPUTERNAME, (Get-Date -Format 'yyyyMMdd-HHmm'))
$report | Set-Content -Path $file -Encoding UTF8

foreach ($w in $warnings) { Write-Warning $w }
Write-Output "Report saved to $file"
