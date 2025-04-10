function AzureStorage_Upload($file, $name) {
    az storage blob upload  `
        --account-name $env:AZURE_STORAGE_ACCOUNT `
        --account-key $env:AZURE_STORAGE_KEY `
        --container-name $env:AZURE_STORAGE_CONTAINER `
        --overwrite $true  `
        --file "$file" `
        --name $name
}

function AzureStorage_GenerateSas($name, $permissions, $expiry) {
    az storage blob generate-sas  `
        --account-name $env:AZURE_STORAGE_ACCOUNT `
        --account-key $env:AZURE_STORAGE_KEY `
        --container-name $env:AZURE_STORAGE_CONTAINER `
        --name $name `
        --full-uri `
        --permissions $permissions `
        --expiry  $expiry
}


$root = [System.IO.Path]::GetFullPath((join-path $PSScriptRoot .. .. .. ..)) 

. "$root/.koksmat/pwsh/check-env.ps1" "AZURE_STORAGE_ACCOUNT", "AZURE_STORAGE_KEY", "AZURE_STORAGE_CONTAINER"
