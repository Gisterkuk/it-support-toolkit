<#
.SYNOPSIS
    Clears a stuck print queue by restarting the Print Spooler service.

.DESCRIPTION
    The most common fix for "I sent it to print and nothing happens": a job gets stuck
    and blocks every job behind it. This script stops the Spooler, deletes the pending
    job files and starts the Spooler again.

    Deletes ALL pending print jobs on this computer, so tell the user to resend what
    they need. Needs an elevated (admin) PowerShell. Use -WhatIf to see what it would do.

.EXAMPLE
    .\Reset-PrintSpooler.ps1 -WhatIf

.EXAMPLE
    .\Reset-PrintSpooler.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param()

$ErrorActionPreference = 'Stop'

$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $WhatIfPreference -and -not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an admin PowerShell (right click > Run as administrator).'
}

$spoolFolder = Join-Path $env:SystemRoot 'System32\spool\PRINTERS'
$jobs = @(Get-ChildItem -Path $spoolFolder -File -ErrorAction SilentlyContinue)
Write-Output "Pending job files: $($jobs.Count)"

if ($PSCmdlet.ShouldProcess('Print Spooler', 'Stop service, delete pending jobs and start again')) {
    Stop-Service -Name Spooler -Force
    (Get-Service -Name Spooler).WaitForStatus('Stopped', [TimeSpan]::FromSeconds(20))

    if ($jobs.Count -gt 0) {
        $jobs | Remove-Item -Force
    }

    Start-Service -Name Spooler
    (Get-Service -Name Spooler).WaitForStatus('Running', [TimeSpan]::FromSeconds(20))
    Write-Output 'Print Spooler restarted and queue cleared. Ask the user to print again.'
}
