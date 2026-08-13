# Setup guide - Extended GPOs Extension

Author(s): G. Lescur - `guillaume.lescur@student.hogent.be`

This guide describes the step-by-step procedure to deploy the Extended GPOs for the Windows clients. It covers the automated steps and the manual steps needed for this.

## Prerequisites

Ensure the following VMs are already running before you start:

- `windowsdc` - Must be fully provisioned
- `winclient` - Must be fully provisioned

## Provisioning workflow

The Windows client Extended GPOs are provisioned in 2 phases.

### Phase 0 - Verify prerequisites

Before starting provisioning, confirm all required VMs are running:

```bash
vagrant status windowsdc
vagrant status winclient
```

All should show as `running`.

### Phase 1 - Make users available on the client

1. Boot the Windows 10 client VM. Log in with the username `DOMAIN404\Administrator` and password `vagrant`.
2. Open Active Directory Users and Computers and move the computerobject `L-26-0001` from `Computers > _Staging` to `Computers > Workstations > IT`.
3. Restart the computer.

### Phase 2 - Log in with the right user

1. After restarting the computer you log in with username `GLE0301` and password `vagrant`

## Verification

Confirm the Extended GPOs are working correctly using these checks:

| Test | Procedure | Expected Result |
| :--- | :--- | :--- |
| **Control panel restrictions** | Try to open the control panel | A ristrictions sign is shown |
| **Background restrictions** | Try to personlize the background by right clicking on the desktop and choosing `Personalize` | You got a warning that stops you from doing this. The background must also be black |
| **taskbar restrictions** | Right-click on the taskbar. Try to pin/unpin apps | You are not able to do this |
| **Edge changes** | Open Edge, close the tabs and re-open it | This shows our domain site as the default page |
| **.Exe restrictions** | Download a .exe file, try to run this in the downloads folder | You get a noticication with the message `This app has been blocked by your system administrator |
