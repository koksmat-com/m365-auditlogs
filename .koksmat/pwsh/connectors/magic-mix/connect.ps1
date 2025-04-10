if ($null -eq $env:WORKDIR ) {
  $env:WORKDIR = join-path $psscriptroot ".." ".koksmat" "workdir"
}
$workdir = $env:WORKDIR

if (-not (Test-Path $workdir)) {
  New-Item -Path $workdir -ItemType Directory | Out-Null
}

$workdir = Resolve-Path $workdir

write-host "Workdir: $workdir"
Push-Location
set-location $workdir
try {
  $magicmixpath = join-path $workdir "magic-mix"
  if (!(Test-Path $magicmixpath) ) {
    git clone --depth=1 https://github.com/magicbutton/magic-mix  
    write-host "Cloned magic-mix"
  
    set-location (Join-Path $workdir magic-mix ".koksmat" "app")
    write-host "Downloading dependencies"
    go mod tidy
    

    write-host "Building magic-mix"
    go build

    Add-Content -Path $env:GITHUB_PATH -Value (Get-Location)

    
    
  }
  $result = magic-mix sql query mix "select 1 as one"
  if ($result -ne '[{"one":1}]') {
    throw "Failed to connect to magic-mix"
  }
  write-host "Magic Mix connection successful"
}
catch {
  write-host "Failed to clone magic-mix"
  throw $_
}
Pop-Location

# write-host "Checking if the command is available"
magic-mix

