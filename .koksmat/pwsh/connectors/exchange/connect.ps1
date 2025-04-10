# https://learn.microsoft.com/en-us/powershell/exchange/app-only-auth-powershell-v2?view=exchange-ps
# Define the module name
$moduleName = 'ExchangeOnlineManagement'

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



$EXCHAPPID = $env:EXCHAPPID
$EXCHORGANIZATION = $env:EXCHORGANIZATION
$EXCHCERTIFICATEPASSWORD = $env:EXCHCERTIFICATEPASSWORD
$EXCHCERTIFICATEPATH = "$PSScriptRoot/certificate.pfx"
$bytes = [Convert]::FromBase64String($ENV:EXCHCERTIFICATE)
[IO.File]::WriteAllBytes($EXCHCERTIFICATEPATH, $bytes)

Write-Output "Connecting to Exchange for $EXCHORGANIZATION"

if (($EXCHCERTIFICATEPASSWORD -ne $null) -and ($EXCHCERTIFICATEPASSWORD -ne "") ) {
	Connect-ExchangeOnline -CertificateFilePath $EXCHCERTIFICATEPATH  -AppID $EXCHAPPID -Organization $EXCHORGANIZATION -ShowBanner:$false -CertificatePassword (ConvertTo-SecureString -String $EXCHCERTIFICATEPASSWORD -AsPlainText -Force)
}
else {
	Connect-ExchangeOnline -CertificateFilePath $EXCHCERTIFICATEPATH  -AppID $EXCHAPPID -Organization $EXCHORGANIZATION -ShowBanner:$false #   -BypassMailboxAnchoring:$true

}							
				