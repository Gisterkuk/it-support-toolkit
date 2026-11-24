# Runbook: "I sent it to print and nothing comes out"

**Goal:** the user prints again in under 10 minutes, and we know the cause.

## 1. Ask (1 minute)
- Which printer, and does it fail for everyone or only for this user?
- Is there an error on the printer screen (paper, toner, jam)?
- Did it ever work from this PC?

If it fails for everyone, the problem is the printer or the network: go to step 4.
If it fails only for this user, the problem is the PC: go to step 2.

## 2. Check the queue on the PC
1. Settings > Bluetooth & devices > Printers & scanners > the printer > **Open print queue**.
2. A job in **Error** or stuck in **Printing** blocks every job behind it.
3. Cancel it. If it does not go away, clear the queue with
   [`Reset-PrintSpooler.ps1`](../windows/Reset-PrintSpooler.ps1) from an admin PowerShell
   (it deletes all pending jobs: the user resends what they need).

## 3. Check that the PC is using the right printer
- The default printer may have changed to "Microsoft Print to PDF" or "OneNote".
- Turn off **Let Windows manage my default printer** if it keeps changing.
- If the printer shows **Offline**, check its IP in the port settings
  (Printer properties > Ports) and ping it.

## 4. Check the printer and the network
- Print a configuration page from the printer panel: it shows its current IP.
- If the IP changed (DHCP), the PCs point to an old address. Fix it with a DHCP
  reservation for the printer, then update the port on the PCs.
- `Test-NetConnection <printer-ip> -Port 9100` (raw printing port) should succeed.

## 5. Close the ticket
- Note the cause (stuck job, wrong default printer, IP changed, hardware).
- If the same printer fails again within a week, open a follow-up for the root cause
  (reservation, driver update, hardware service).
