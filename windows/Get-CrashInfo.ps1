<#
.SYNOPSIS
    Finds evidence of blue screens, unexpected shutdowns and app crashes on a Windows PC.

.DESCRIPTION
    When a user says "the PC restarted by itself" or "the program keeps closing", this
    script gathers in one place:
      - memory dumps (C:\Windows\Minidump\*.dmp and C:\Windows\MEMORY.DMP)
      - BugCheck events (blue screens)              System log, Event ID 1001
      - Kernel-Power 41 (lost power or hard reset)  System log, Event ID 41
      - Unexpected shutdowns                         System log, Event ID 6008
      - Application crashes and hangs                Application log, Event IDs 1000 and 1002

    Read-only. Run it from an admin PowerShell to be able to list the dump files.
    To analyse a dump, open it in WinDbg and run: !analyze -v

.PARAMETER Days
    How many days back to look. Default: 30.

.EXAMPLE
    .\Get-CrashInfo.ps1 -Days 7
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 365)]
    [int]$Days = 30
)

$since = (Get-Date).AddDays(-$Days)

function Get-EventSafe {
    param([hashtable]$Filter)
    try {
        Get-WinEvent -FilterHashtable $Filter -ErrorAction Stop
    } catch {
        if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') {
            Write-Warning "Could not read $($Filter.LogName): $($_.Exception.Message)"
        }
    }
}

function Get-FirstLine {
    param([string]$Text, [int]$MaxLength = 110)
    if (-not $Text) { return '(no message)' }
    $line = ($Text -split "`r?`n")[0]
    if ($line.Length -gt $MaxLength) { $line = $line.Substring(0, $MaxLength) + '...' }
    return $line
}

Write-Output "Crash evidence for $($env:COMPUTERNAME), last $Days days"
Write-Output ('=' * 60)

Write-Output ''
Write-Output '[Memory dumps]'
$dumps = @()
$dumps += Get-ChildItem -Path (Join-Path $env:SystemRoot 'Minidump') -Filter '*.dmp' -ErrorAction SilentlyContinue
$fullDump = Join-Path $env:SystemRoot 'MEMORY.DMP'
if (Test-Path $fullDump) { $dumps += Get-Item $fullDump -ErrorAction SilentlyContinue }
if ($dumps) {
    $dumps | Sort-Object LastWriteTime -Descending |
        Select-Object LastWriteTime, @{ n = 'SizeMB'; e = { [math]::Round($_.Length / 1MB, 1) } }, FullName |
        Format-Table -AutoSize | Out-String | Write-Output
} else {
    Write-Output 'No dump files found (or no permission to read them: try an admin PowerShell).'
}

$checks = @(
    @{ Title = 'Blue screens (BugCheck 1001)';            Filter = @{ LogName = 'System';      Id = 1001; StartTime = $since; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting' } },
    @{ Title = 'Lost power / hard reset (Kernel-Power 41)'; Filter = @{ LogName = 'System';      Id = 41;   StartTime = $since } },
    @{ Title = 'Unexpected shutdowns (6008)';             Filter = @{ LogName = 'System';      Id = 6008; StartTime = $since } },
    @{ Title = 'Application crashes (1000)';              Filter = @{ LogName = 'Application'; Id = 1000; StartTime = $since } },
    @{ Title = 'Application hangs (1002)';                Filter = @{ LogName = 'Application'; Id = 1002; StartTime = $since } }
)

foreach ($check in $checks) {
    Write-Output ''
    Write-Output "[$($check.Title)]"
    $found = @(Get-EventSafe -Filter $check.Filter)
    if ($found.Count -eq 0) {
        Write-Output 'None.'
        continue
    }
    $found | Select-Object -First 10 TimeCreated, @{ n = 'Detail'; e = { Get-FirstLine $_.Message } } |
        Format-Table -AutoSize -Wrap | Out-String | Write-Output
    if ($found.Count -gt 10) { Write-Output "... and $($found.Count - 10) more." }
}

Write-Output ''
Write-Output 'Tip: the same crashing app (1000) every day usually means a broken update or add-in;'
Write-Output 'repeated Kernel-Power 41 without a BugCheck usually points to power, PSU or overheating.'
