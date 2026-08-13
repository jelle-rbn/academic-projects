# Cheat-sheet

Author(s): G. Lescur - `guillaume.lescur@student.hogent.be`

This document provides a quick reference for common commands used for the GPOs on the windows client.

## Group policies

| Command | Description |
| :--- | :--- |
| `gpresult /r` | Shows what GPOs are applied to current user and computer |
| `gpupdate /force` | Force Group Policy update after changes |

## Powershell

| Command | Description |
| :--- | :--- |
| `whoami` | Check current user |
| `whoami /all` | Check current user |
| `Get-ADComputer L-26-00001 -Properties DistinguishedName` | Verify OU |
| `shutdown /r /t 0` | Restart computer from command line |


## Extra

| Command | Description |
| :--- | :--- |
| `rsop.msc` | Get GUI-overview of all applied policies |
| `gpedit.msc` | Open Group Policy editor locally |
