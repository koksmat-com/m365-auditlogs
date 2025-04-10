# Define the module name
$moduleName = 'PnP.PowerShell'

# Attempt to get the installed module
$module = Get-InstalledModule -Name $moduleName -ErrorAction SilentlyContinue

if ($null -eq $module) {
  # Module is not installed, proceed with installation
  Write-Host "Installing $moduleName..." -ForegroundColor Green
  try {
    Install-Module -Name $moduleName -Force -AllowPrerelease -Scope CurrentUser
    Write-Host "$moduleName has been successfully installed." -ForegroundColor Cyan
  }
  catch {
    Write-Host "Failed to install $moduleName. $_" -ForegroundColor Red
  }
}
else {
  # Module is already installed
  Write-Host "$moduleName is already installed. Version $($module.Version)." -ForegroundColor Yellow
}


$PNPAPPID = $env:PNPAPPID
$PNPTENANTID = $env:PNPTENANTID
$PNPCERTIFICATEPATH = "$($PSScriptRoot)/pnp.pfx"
$PNPSITE = $env:PNPSITE
$bytes = [Convert]::FromBase64String($ENV:PNPCERTIFICATE)
[IO.File]::WriteAllBytes($PNPCERTIFICATEPATH, $bytes)

write-output "Connecting to $PNPSITE"
Connect-PnPOnline -Url $PNPSITE  -ClientId $PNPAPPID -Tenant $PNPTENANTID -CertificatePath "$PNPCERTIFICATEPATH"
# Load modules
. "$PSScriptRoot/readlist.ps1" 