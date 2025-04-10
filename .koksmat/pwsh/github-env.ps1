<#---
title: "GitHub Environment Variables Script"
description: "A PowerShell script to parse .env files and generate a script to set GitHub repository variables or secrets."
platform: "PowerShell"
categories: ["automation", "github", "powershell"]
tags: ["automation", "github", "powershell", "script", "variables", "secrets"]
authors: ["koksmat"]

---
#>
param (
  [string]$OutputFile = "github-env.temp.ps1"
)

# If the output file already exists, remove it to start fresh
if (Test-Path $OutputFile) {
  Remove-Item $OutputFile
}
<#
## STEP 1: Find a list of .env files starting from current directory going upwards

#>
$envFiles = New-Object System.Collections.Generic.List[string]
$currentDir = (Get-Location).ProviderPath

while ($true) {
  $envPath = Join-Path $currentDir ".env"
  if (Test-Path $envPath) {
    $envFiles.Add($envPath)
  }

  $parent = Split-Path $currentDir
  if ([string]::IsNullOrEmpty($parent) -or $parent -eq $currentDir) {
    break
  }
  $currentDir = $parent
}
<#
## STEP 2: Output the full path of each found .env file to the console
#>
Write-Host "Found the following .env files:"
$envFiles = $envFiles | Sort-Object Length

foreach ($file in $envFiles) {
  Write-Host $file
}

"`$envVars = @{}" | Out-File -FilePath $OutputFile -Append -Encoding UTF8
<#
## STEP 3: Parse and write environment variables from each found .env file into the output file
Note: The first found is from the closest directory, then upwards.
#>
foreach ($envPath in $envFiles) {
  "`n#--------------------------------------" | Out-File -FilePath $OutputFile -Append -Encoding UTF8
  "# $envPath" | Out-File -FilePath $OutputFile -Append -Encoding UTF8
  "#--------------------------------------" | Out-File -FilePath $OutputFile -Append -Encoding UTF8

  $lines = Get-Content $envPath
  foreach ($line in $lines) {
    $trimmedLine = $line.Trim()

    # Skip empty and comment lines
    if ([string]::IsNullOrWhiteSpace($trimmedLine) -or $trimmedLine.StartsWith("#")) {
      continue
    }

    # Parse KEY=VALUE
    $splitIndex = $trimmedLine.IndexOf("=")
    if ($splitIndex -gt 0) {
      $key = $trimmedLine.Substring(0, $splitIndex).Trim()
      $value = $trimmedLine.Substring($splitIndex + 1).Trim()

      # If value isn't quoted, add quotes
      if (-not (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))) {
        $value = "`"$value`""
      }

      ($dollar + "`$envVars[`"$key`"] = $value") | Out-File -FilePath $OutputFile -Append -Encoding UTF8
    }
  }
}
<#
## STEP 4: Add the script to set GitHub repository variables or secrets
#>

@'

#--------------------------------------
#  End of .env files
#
#  Applying Addtional settings
# 
#--------------------------------------
# Initialize the output content array for the script
function Contains-Word {
    param (
        [Parameter(Mandatory)]
        [string]$InputString,

        [Parameter(Mandatory)]
        [string[]]$WordArray
    )

    # Iterate over the words in the array and check for their presence in the input string
    foreach ($word in $WordArray) {
        # -match is case-insensitive by default
        if ($InputString -match "$word") {
            return $true
        }
    }

    return $false
}



$secretWords = @("SECRET", "DB", "DATABASE","CERTIFICATE","PASSWORD","TOKEN","KEY","SAAS")

$outputFilePath = "$psscriptroot\github-env.temp.ps1"
$outputContent = @(
  "# Auto-generated script to set GitHub repo variables or secrets"
  "# Ensure that you have authenticated with gh CLI before running this script"
  "# Usage: gh auth login"
)

# Use the hash table to generate GitHub variable and secret assignments
foreach ($key in $envVars.Keys) {
  $value = $envVars[$key]
  if (Contains-Word -InputString $key -WordArray $secretWords) {
    $outputContent += "gh secret set $key --body `"$value`""
  }
  else {
    $outputContent += "gh variable set $key --body `"$value`""
  }
}

# Write the output content to the script file
$outputContent | Set-Content -Path $outputFilePath

# Output the hash table for debugging purposes
Write-Host "Environment Variables Loaded:"
$envVars.GetEnumerator() | ForEach-Object { Write-Host "$($_.Key) = $($_.Value)" }

Write-Host "Script written to $outputFilePath"
Write-Host "Run the script with: .\$outputFilePath"


'@ | Out-File -FilePath $OutputFile -Append -Encoding UTF8

