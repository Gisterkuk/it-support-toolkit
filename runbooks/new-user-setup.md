# Runbook: new employee setup (Active Directory domain)

**Goal:** the new person can sign in, print and do their job on day one.

## Before the first day
- [ ] Ticket from HR with: full name, area, manager, start date, which systems they need.
- [ ] Create the user in **Active Directory Users and Computers**, in the OU of their area
      (the OU decides which group policies apply).
- [ ] Naming rule for the username, and a temporary password with
      **User must change password at next logon**.
- [ ] Add the user to the groups of their area (shared folders, printers, apps).
      Copying the groups of a colleague in the same role is faster, but review them:
      do not copy permissions they should not have.
- [ ] Email account and the licenses they need.

## The workstation
- [ ] PC joined to the domain, with the computer object in the right OU.
- [ ] Sign in once with the new user and run `gpupdate /force` so the policies apply now.
- [ ] Check mapped drives and the default printer.
- [ ] Office apps installed and signed in.
- [ ] Remote support tool installed (AnyDesk or TeamViewer) and the ID written in the asset sheet.
- [ ] Run [`Get-SystemReport.ps1`](../windows/Get-SystemReport.ps1) and attach the report to the ticket
      (serial number, model and OS for the asset inventory).

## Day one
- [ ] The person changes the temporary password.
- [ ] Show them how to ask for help (ticket system, phone, chat).
- [ ] Close the ticket with what was delivered (PC, accesses, accounts).

## When someone leaves
Disable the account the same day (do not delete it yet), remove the groups, reset the
password, and move the files the area needs before deleting anything.
