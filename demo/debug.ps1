
Push-Location
try {
  Set-Location $PSScriptRoot
  
  . "$PSScriptRoot/../.koksmat/pwsh/build-env.ps1"
  . "$PSScriptRoot/temp.ps1"
  . "$PSScriptRoot/run.ps1"
}
catch {
  write-host "Error: $_" -ForegroundColor:Red
  <#Do this if a terminating exception happens#>
}
finally {
  Pop-Location
}