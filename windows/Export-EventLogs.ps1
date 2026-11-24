<#
.SYNOPSIS
    Exports the recent errors from the Windows event logs to a CSV and shows a summary.

.DESCRIPTION
    Collects Critical and Error events (and optionally Warnings) from the chosen logs for
    the last N days, saves them to a CSV you can attach to a ticket or open in Excel, and
    prints the sources that fail the most, which is usually where to start looking.

    With -ExportEvtx it also saves the raw .evtx files, so a second-level team can open
    them in Event Viewer. Reading the Security log, and exporting some .evtx files,
    needs an elevated (admin) PowerShell.

.PARAMETER Days
    How many days back to look. Default: 7.

.PARAMETER LogName
    Logs to read. Default: System and Application.

.PARAMETER IncludeWarnings
    Also include Warning events.

.PARAMETER ExportEvtx
    Also export each log as an .evtx file for the same time window.

.PARAMETER OutputPath
    Folder for the output files. Default: the current user's Desktop.

.EXAMPLE
    .\Export-EventLogs.ps1

.EXAMPLE
    .\Export-EventLogs.ps1 -Days 2 -IncludeWarnings -ExportEvtx -OutputPath C:\Temp\ticket-1234
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 90)]
    [int]$Days = 7,

    [string[]]$LogName = @('System', 'Application'),

    [switch]$IncludeWarnings,

    [switch]$ExportEvtx,

    [string]$OutputPath = [Environment]::GetFolderPath('Desktop')
)

$ErrorActionPreference = 'Stop'

# Event levels: 1 = Critical, 2 = Error, 3 = Warning.
$levels = @(1, 2)
if ($IncludeWarnings) { $levels += 3 }
$since = (Get-Date).AddDays(-$Days)

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'

$events = foreach ($log in $LogName) {
    try {
        Get-WinEvent -FilterHashtable @{ LogName = $log; Level = $levels; StartTime = $since } -ErrorAction Stop
    } catch [System.Exception] {
        if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') {
            Write-Verbose "No matching events in $log."
        } else {
            Write-Warning "Could not read the $log log: $($_.Exception.Message)"
        }
    }
}

$rows = $events | Sort-Object TimeCreated -Descending | ForEach-Object {
    $firstLine = if ($_.Message) { ($_.Message -split "`r?`n")[0] } else { '(no message)' }
    [pscustomobject]@{
        Time     = $_.TimeCreated
        Log      = $_.LogName
        Level    = $_.LevelDisplayName
        Source   = $_.ProviderName
        EventId  = $_.Id
        Message  = $firstLine
    }
}

$csv = Join-Path $OutputPath "$($env:COMPUTERNAME)-events-$stamp.csv"
if ($rows) {
    $rows | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
    Write-Output "$(@($rows).Count) events from the last $Days days saved to $csv"
    Write-Output ''
    Write-Output 'Sources with the most events:'
    $rows |
        Group-Object Source, EventId |
        Sort-Object Count -Descending |
        Select-Object -First 10 Count, @{ n = 'Source / EventId'; e = { $_.Name } } |
        Format-Table -AutoSize |
        Out-String |
        Write-Output
} else {
    Write-Output "No Critical or Error events in the last $Days days. Good sign."
}

if ($ExportEvtx) {
    $ms = [int64]((Get-Date) - $since).TotalMilliseconds
    foreach ($log in $LogName) {
        $evtx = Join-Path $OutputPath "$($env:COMPUTERNAME)-$log-$stamp.evtx"
        & wevtutil.exe epl $log $evtx "/q:*[System[TimeCreated[timediff(@SystemTime) <= $ms]]]"
        if ($LASTEXITCODE -eq 0) {
            Write-Output "Exported $log to $evtx"
        } else {
            Write-Warning "Could not export $log (try an admin PowerShell)."
        }
    }
}
