# Runbook: "My computer is very slow"

**Goal:** find the cause with data before reinstalling anything.

## 1. Collect the basics (2 minutes)
Run [`Get-SystemReport.ps1`](../windows/Get-SystemReport.ps1) on the PC (no admin needed).
It saves a report on the Desktop and flags the usual suspects:

| Warning in the report | Usual cause | What to do |
|---|---|---|
| No restart in many days | Memory leaks, pending updates | Restart and check again |
| Windows waiting for a restart | Updates half installed | Restart outside working hours |
| Memory 90%+ used | Too many apps or browser tabs, or too little RAM | Look at the top processes; consider more RAM |
| Disk under 15% free | Temp files, Downloads, old profiles | Disk Cleanup, empty Downloads, move files to the server |

## 2. Look at what is busy right now
- Task Manager > Processes, sorted by CPU, Memory and Disk.
- A disk at 100% on an old HDD is the most common cause in older PCs: an SSD fixes it.
- Antivirus scans or Windows Update running in the background are temporary: check again later.

## 3. Check for errors
Run [`Export-EventLogs.ps1`](../windows/Export-EventLogs.ps1) `-Days 7`.
Many disk errors (source `disk` or `Ntfs`) mean a failing drive: back up the user's files first.

## 4. Startup programs
Task Manager > Startup apps: disable what the user does not need at sign-in.

## 5. Close the ticket
Write down what you found (with the report attached) and what you changed.
If the hardware is the limit (RAM, HDD), propose the upgrade with the data from the report.
