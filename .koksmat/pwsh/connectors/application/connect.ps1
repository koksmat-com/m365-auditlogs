function FindSiteIdByUrl($token, $siteUrl) {
    $Xheaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Xheaders.Add("Content-Type", "application/json")
    $Xheaders.Add("Prefer", "apiversion=2.1") ## Not compatibel when reading items from SharePointed fields 
    $Xheaders.Add("Authorization", "Bearer $token" )

    $url = 'https://graph.microsoft.com/v1.0/sites/?$top=1'
    $topItems = Invoke-RestMethod $url -Method 'GET' -Headers $Xheaders 
    if ($topItems.Length -eq 0) {
        Write-Warning "Cannot read sites from Office Graph - sure permissions are right?"
        exit
    }
    $siteUrl = $siteUrl.replace("sharepoint.com/", "sharepoint.com:/")
    $siteUrl = $siteUrl.replace("https://", "")

    $Zheaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Zheaders.Add("Content-Type", "application/json")
    $Zheaders.Add("Authorization", "Bearer $token" )
    

    $url = 'https://graph.microsoft.com/v1.0/sites/' + $siteUrl 

    $site = Invoke-RestMethod $url -Method 'GET' -Headers $Zheaders 
   

    return  $site.id
}
function GraphAPI($token, $method, $url, $body, $headers) {
    if ($null -eq $headers) {
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Content-Type", "application/json")
        $headers.Add("Accept", "application/json")
        $headers.Add("Authorization", "Bearer $token" )
    }
    else {
        $headers.Add("Accept", "application/json")
        $headers.Add("Authorization", "Bearer $token" )
    }
    
    
    $errorCount = $error.Count
    $result = Invoke-RestMethod ($url) -Method $method -Headers $headers -Body $body
    if ($errorCount -ne $error.Count) {
        Write-Error $url
    }

    return $result

}

<#
.description
Read from Graph and follow @odata.nextLink
.changes
v1.03 Removed -Body from Invoke-RestMethod
#>
function GraphAPIAll($token, $method, $url) {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    $headers.Add("Accept", "application/json")
    $headers.Add("Authorization", "Bearer $token" )
    
    $errorCount = $error.Count
    $result = Invoke-RestMethod ($url) -Method $method -Headers $headers 
    if ($errorCount -ne $error.Count) {
        Write-Error $url
    }


    $data = $result.value
    $counter = 0
    while ($result.'@odata.nextLink') {
        Write-Progress -Activity "Reading from GraphAPIAll $path" -Status "$counter Items Read" 

        if ($hexatown.verbose) {
            write-output "GraphAPIAll $($result.'@odata.nextLink')"
        }
        $result = Invoke-RestMethod ($result.'@odata.nextLink') -Method 'GET' -Headers $headers 
        $data += $result.value
        $counter += $result.value.Count
        
    }

    return $data

}


# Convert the base64 string to byte array
$certBytes = [System.Convert]::FromBase64String($env:APP_APPLICATION_CERTIFICATE)
# -----------------------------
# Complete Revised PowerShell Script to Obtain Access Token and Call Microsoft Graph
# -----------------------------

# -----------------------------
# Variables
# -----------------------------

# Azure AD Tenant ID
$tenantId = $env:APP_APPLICATION_DOMAIN

# Azure AD Application (Client) ID
$clientId = $env:APP_APPLICATION_ID

# Scope for Microsoft Graph
$scope = "https://graph.microsoft.com/.default"

# Base64-Encoded PFX Certificate String (Without Password)
$certBase64 = $env:APP_APPLICATION_CERTIFICATE




# -----------------------------
# Function to Decode and Import Certificate Using Constructor
# -----------------------------

function Get-CertificateFromBase64 {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Base64String
    )

    # Remove PEM headers/footers and whitespace
    $certBase64Clean = ($Base64String -replace "-----BEGIN CERTIFICATE-----", "") `
        -replace "-----END CERTIFICATE-----", "" `
        -replace "\s", ""

    # Convert base64 string to byte array
    $certBytes = [System.Convert]::FromBase64String($certBase64Clean)

    # Create a new X509Certificate2 object using the constructor
    try {
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 (
            $certBytes,
            $null,
            [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
        )
    }
    catch {
        Write-Error "Failed to create X509Certificate2 object. Ensure the base64 string is a valid PFX certificate containing a private key."
        throw $_
    }

    return $cert
}

# -----------------------------
# Decode Base64 and Import Certificate
# -----------------------------

$cert = Get-CertificateFromBase64 -Base64String $certBase64

# Verify that the certificate has a private key
if (-not $cert.HasPrivateKey) {
    Write-Error "The certificate does not contain a private key."
    exit
}

Write-Output "Certificate imported successfully. Subject: $($cert.Subject)"

# Function to calculate SHA-256 Thumbprint
function Get-SHA256Thumbprint {
    param (
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )

    # Compute SHA-256 hash of the certificate's raw data
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hash = $sha256.ComputeHash($Certificate.RawData)

    # Convert hash to Base64Url encoding
    $base64UrlThumbprint = [Convert]::ToBase64String($hash) -replace '\+', '-' -replace '/', '_' -replace '=', ''

    return $base64UrlThumbprint
}

# Example usage after importing the certificate
$sha256Thumbprint = Get-SHA256Thumbprint -Certificate $cert
Write-Output "SHA-256 Thumbprint (x5t#S256): $sha256Thumbprint"

# -----------------------------
# Create JWT Header and Payload
# -----------------------------

# Current Unix timestamp
$currentTime = [Math]::Round((Get-Date -UFormat %s))

# JWT Header
$jwtHeader = @{
    alg        = "RS256"
    typ        = "JWT"
    'x5t#S256' = $sha256Thumbprint
} | ConvertTo-Json -Compress

# JWT Payload
$jwtPayload = @{
    aud = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    iss = $clientId
    sub = $clientId
    jti = [guid]::NewGuid().ToString()
    exp = $currentTime + 3600  # Token valid for 1 hour
} | ConvertTo-Json -Compress

# Function to Base64Url Encode
function Base64UrlEncode($txt) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($txt)
    $base64 = [Convert]::ToBase64String($bytes)
    # Convert to Base64Url by replacing + with -, / with _, and removing =
    $base64Url = $base64.TrimEnd('=') -replace '\+', '-' -replace '/', '_'
    return $base64Url
}

# Encode Header and Payload
$encodedHeader = Base64UrlEncode $jwtHeader
$encodedPayload = Base64UrlEncode $jwtPayload

# Debugging Output
Write-Output "Encoded Header: $encodedHeader"
Write-Output "Encoded Payload: $encodedPayload"

# Concatenate Header and Payload
$stringToSign = "$encodedHeader.$encodedPayload"

# Debugging Output
Write-Output "String to Sign: $stringToSign"

# -----------------------------
# Sign the JWT Using PrivateKey Property
# -----------------------------

# Convert the string to sign into bytes
$bytesToSign = [System.Text.Encoding]::UTF8.GetBytes($stringToSign)

# Create a SHA256 hash of the string
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$hash = $sha256.ComputeHash($bytesToSign)

# Access the RSA private key using the PrivateKey property
$rsa = $cert.PrivateKey

if ($rsa -is [System.Security.Cryptography.RSACryptoServiceProvider]) {
    # For RSACryptoServiceProvider
    try {
        $signature = $rsa.SignHash($hash, [System.Security.Cryptography.CryptoConfig]::MapNameToOID("SHA256"))
    }
    catch {
        Write-Error "Failed to sign the JWT using RSACryptoServiceProvider. $_"
        exit
    }
}
elseif ($rsa -is [System.Security.Cryptography.RSA]) {
    # For RSACng or other RSA implementations
    try {
        $signature = $rsa.SignHash($hash, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    }
    catch {
        Write-Error "Failed to sign the JWT using RSA. $_"
        exit
    }
}
else {
    Write-Error "Unsupported RSA private key type."
    exit
}

# Base64Url Encode the Signature
$signatureBase64 = [Convert]::ToBase64String($signature)
$signatureEncoded = $signatureBase64.TrimEnd('=') -replace '\+', '-' -replace '/', '_'

# Create the JWT Assertion
$jwtAssertion = "$stringToSign.$signatureEncoded"

# Debugging Output
Write-Output "JWT Assertion: $jwtAssertion"

# -----------------------------
# Prepare the Token Request
# -----------------------------

# Token Endpoint
$tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

# Prepare the request body
$body = @{
    client_id             = $clientId
    scope                 = $scope
    grant_type            = "client_credentials"
    client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
    client_assertion      = $jwtAssertion
}

# Convert the body to application/x-www-form-urlencoded format
$bodyFormUrlEncoded = ($body.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '&'

# Debugging Output
Write-Output "Token Request Body: $bodyFormUrlEncoded"

# -----------------------------
# Make the Token Request
# -----------------------------

try {
    $response = Invoke-RestMethod -Method Post -Uri $tokenEndpoint `
        -ContentType "application/x-www-form-urlencoded" `
        -Body $bodyFormUrlEncoded
}
catch {
    Write-Error "Failed to obtain access token. $_"
    exit
}

# Extract the access token
$accessToken = $response.access_token

if ($accessToken) {
    Write-Output "Access Token Obtained Successfully."
}
else {
    Write-Error "Failed to obtain access token."
    exit
}

# -----------------------------
# Make a Microsoft Graph API Call
# -----------------------------

# Example: Retrieve a List of Users
$graphApiEndpoint = "https://graph.microsoft.com/v1.0/users"

try {
    $graphResponse = Invoke-RestMethod -Method Get -Uri $graphApiEndpoint `
        -Headers @{ "Authorization" = "Bearer $accessToken" }

    # Display the list of users
    $graphResponse.value | Select-Object displayName, mail, userPrincipalName
}
catch {
    Write-Error "Failed to call Microsoft Graph API. $_"
}


$env:APP_ACCESSTOKEN = $accessToken


