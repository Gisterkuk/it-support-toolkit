# IT Support Toolkit

Scripts and runbooks for everyday IT support on Windows and Linux: collect the facts of a
ticket in two minutes, find the cause with data, and leave a written record.

Built around the tickets I handle most in my support work: slow PCs, printers, network
problems, crashes, new users and server checks. Every script is **read-only unless its
name says otherwise** (`Reset-*`), and each one explains itself with `Get-Help`.

## What's inside

| Path | What it does | Admin? |
|---|---|---|
| [`windows/Get-SystemReport.ps1`](windows/Get-SystemReport.ps1) | One text report of a PC for the ticket: OS, uptime, CPU, memory, disks, network, pending reboot, latest updates, top processes. Flags the usual problems. | No |
| [`windows/Export-EventLogs.ps1`](windows/Export-EventLogs.ps1) | Exports Critical and Error events of the last N days to CSV (and optionally `.evtx`), and shows the sources that fail the most. | No (yes for some `.evtx`) |
| [`windows/Get-CrashInfo.ps1`](windows/Get-CrashInfo.ps1) | Evidence of blue screens, unexpected shutdowns and app crashes: memory dumps and Event IDs 1001, 41, 6008, 1000, 1002. | To list dumps |
| [`windows/Test-NetworkBasics.ps1`](windows/Test-NetworkBasics.ps1) | Tests IP, gateway, internet, DNS and HTTPS in order; the first FAIL says where to look. | No |
| [`windows/Reset-PrintSpooler.ps1`](windows/Reset-PrintSpooler.ps1) | Clears a stuck print queue (supports `-WhatIf`). | Yes |
| [`linux/server-health.sh`](linux/server-health.sh) | One-screen server check: load, memory, disks, failed services, Docker containers, reboots, ports. Exit code 1 on warnings, for cron. | No |
| [`docker/uptime-kuma`](docker/uptime-kuma/docker-compose.yml) | Self-hosted monitor for websites, servers and devices, with alerts. | Docker |
| [`runbooks/`](runbooks) | Step-by-step guides: [printer not printing](runbooks/printer-not-printing.md), [slow computer](runbooks/slow-computer.md), [new user setup](runbooks/new-user-setup.md). | - |

## Quick start

**Windows** (PowerShell 5.1 or 7):

```powershell
# Allow local scripts for this session only
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

.\windows\Get-SystemReport.ps1
.\windows\Test-NetworkBasics.ps1
.\windows\Export-EventLogs.ps1 -Days 3 -IncludeWarnings
Get-Help .\windows\Get-CrashInfo.ps1 -Full
```

**Linux:**

```bash
chmod +x linux/server-health.sh
./linux/server-health.sh
# In cron, with custom thresholds:
DISK_WARN=80 MEM_WARN=85 ./linux/server-health.sh || echo "check the server"
```

## How I use it on a ticket

1. Run the report or the check that matches the problem and attach the output.
2. Follow the runbook, writing down what I checked and what I changed.
3. Close the ticket with the cause, so the next time it takes less.

## Quality

Every push runs [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) on the
PowerShell scripts and [ShellCheck](https://www.shellcheck.net/) on the shell script, and
runs the Linux health check on a clean Ubuntu machine (see [the workflow](.github/workflows/lint.yml)).

## About

I'm Alan Vega, IT support and web developer in Argentina (Spanish, Portuguese, English).
More of my work: [alanvega.dev](https://alanvega.dev).

MIT License.
