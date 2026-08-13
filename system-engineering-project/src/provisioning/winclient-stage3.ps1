# -----------------------------------------------------------------------------
# winclient-stage3.ps1  --  RSAT, Software & Network Fix
# -----------------------------------------------------------------------------
# Ensures the client is domain joined, installs RSAT, installs software via
# Chocolatey and applies the full network fix last so all downloads can use
# the NAT interface before switching to onsite routing.
#
# USAGE (run as Administrator after stage 2 reboot):
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   C:\provisioning\winclient-stage3.ps1
#
# No reboot needed after this -- provisioning is complete.
# -----------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'
. "C:\provisioning\win-config.ps1"

# -- Pre-requisite Check ------------------------------------------------------
Assert-DomainMembership

# -- DNS Registration ---------------------------------------------------------
Write-Host "Re-registering DNS"
ipconfig /registerdns | Out-Null
Write-Host "DNS re-registration OK"

# -- Network Fix  -------------------------------------------------------------
# Removes the NAT default route and promotes the VLAN gateway to default,
# switching the machine to onsite routing mode.
Write-Host "Applying network fix"
Invoke-NetworkFix -Gateway $clientGateway

# -- Script Completion --------------------------------------------------------
Start-Sleep -Seconds 3
Write-Host ""
Write-Host "  +-------------------------------------------------+"
Write-Host "  |                                                 |"
Write-Host "  |    Windows 10 client -- Ready!                  |"
Write-Host "  |                                                 |"
Write-Host "  |    Enter to exit                                |"
Write-Host "  |                                                 |"
Write-Host "  +-------------------------------------------------+"
Write-Host ""

Read-Host
Restart-Computer -Force
exit 0
