function Set-KoksmatWorkdir() {
  if ($null -eq $env:WORKDIR ) {
    $env:WORKDIR = join-path $psscriptroot "." "workdir"
  }
  $workdir = $env:WORKDIR

  if (-not (Test-Path $workdir)) {
    New-Item -Path $workdir -ItemType Directory | Out-Null
  }

  $workdir = Resolve-Path $workdir

  
  Push-Location
  set-location $workdir
  return $workdir
}