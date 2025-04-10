try {
    

    # Variables
    $appId = $env:GITHUB_APPID           
    $installationId = $env:GITHUB_APPID 
    

    # Retrieve the private key from an environment variable
    $privateKey = $env:GITHUB_PRIVATE_KEY 

    if (-not $privateKey) {
        Write-Error "Private key environment variable (GITHUB_PRIVATE_KEY) is not set."
        exit 1
    }
    #!/usr/bin/env pwsh

    $client_id = $env:GITHUB_CLIENTID



    $header = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject @{
                    alg = "RS256"
                    typ = "JWT"
                }))).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    $payload = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject @{
                    iat = [System.DateTimeOffset]::UtcNow.AddSeconds(-10).ToUnixTimeSeconds()
                    exp = [System.DateTimeOffset]::UtcNow.AddMinutes(10).ToUnixTimeSeconds()
                    iss = $client_id 
                }))).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    $rsa = [System.Security.Cryptography.RSA]::Create()
    $rsa.ImportFromPem($privateKey)

    $signature = [Convert]::ToBase64String($rsa.SignData([System.Text.Encoding]::UTF8.GetBytes("$header.$payload"), [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    $jwt = "$header.$payload.$signature"
    Write-Host $jwt

    # Exchange JWT for Access Token
    $githubApiUrl = "https://api.github.com/app/installations/$installationId/access_tokens"

    write-host $githubApiUrl
    $response = Invoke-RestMethod -Uri $githubApiUrl -Method POST -Headers @{
        Authorization          = "Bearer $jwt"
        Accept                 = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
    $accessToken = $response.token
    $env:GITHUB_TOKEN = $accessToken

}
catch {
    Write-Host "Failed to connect to GitHub: $_" -ForegroundColor Red
    throw "Failed to connect to GitHub: $_"
}