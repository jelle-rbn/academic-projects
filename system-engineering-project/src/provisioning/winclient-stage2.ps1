# -----------------------------------------------------------------------------
# winclient-stage2.ps1  --  Domain Join
# -----------------------------------------------------------------------------
#
# USAGE (run as Administrator after stage 1 reboot):
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   C:\provisioning\winclient-stage2.ps1
#
# Reboot manually when complete, then run winclient-stage3.ps1.
# -----------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'
. "C:\provisioning\win-config.ps1"

# -- Execute Domain Join ------------------------------------------------------
Invoke-DomainJoin

# -- Script Completion --------------------------------------------------------
Start-Sleep -Seconds 3
Write-Host ""
Write-Host "  +-------------------------------------------------+"
Write-Host "  | Stage 2 complete - Enter to reboot              |"
Write-Host "  | After reboot, run: winclient-stage3.ps1         |"
Write-Host "  +-------------------------------------------------+"
Write-Host ""

Read-Host
Restart-Computer -Force
exit 0
