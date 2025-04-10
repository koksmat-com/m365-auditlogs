# Step 1: Get Access Token from ENV
$tenantId = $env:GRAPH_TENANT_ID
$clientId = $env:GRAPH_CLIENT_ID
$clientSecret = $env:GRAPH_CLIENT_SECRET
$targetUpn = $env:GRAPH_TARGET_UPN       # Email recipient + OneDrive owner
$mailFromUpn = $env:GRAPH_MAIL_FROM_UPN    # Sender mailbox

if (-not ($tenantId -and $clientId -and $clientSecret -and $targetUpn -and $mailFromUpn)) {
    throw "Missing one or more required environment variables."
}

# Step 2: Authenticate
$body = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = "https://graph.microsoft.com/.default"
}
$tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Body $body
$accessToken = $tokenResponse.access_token
$headers = @{ Authorization = "Bearer $accessToken" }

# Step 3: Pull Sign-ins (paged)
$signIns = @()
$url = "https://graph.microsoft.com/v1.0/auditLogs/signIns"
while ($url) {
    $response = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
    $signIns += $response.value
    $url = $response.'@odata.nextLink'
}

$timestamp = (Get-Date).ToString("yyyy-MM-dd_HHmmss")

if (-not $env:TEMP) {
    $env:TEMP = [System.IO.Path]::GetTempPath()
}
$tempFolder = Join-Path $env:TEMP "audit_$timestamp"
New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null
$signInFile = Join-Path $tempFolder "signins.json"
$signIns | ConvertTo-Json -Depth 10 | Set-Content -Path $signInFile -Encoding utf8
Write-Host "✅ Collected $($signIns.Count) sign-ins."

# Step 4: Audit logs for first user
$firstUserId = $signIns[0].userId
$auditLogs = @()
$url = "https://graph.microsoft.com/v1.0/auditLogs/directoryAudits?`$filter=userId eq '$firstUserId'"
while ($url) {
    $response = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
    $auditLogs += $response.value
    $url = $response.'@odata.nextLink'
}

$auditFile = Join-Path $tempFolder "auditlogs.json"
$auditLogs | ConvertTo-Json -Depth 10 | Set-Content -Path $auditFile -Encoding utf8
Write-Host "✅ Collected $($auditLogs.Count) audit logs for $firstUserId"

# Step 5: Upload to OneDrive of $targetUpn
$driveResponse = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users/$targetUpn/drive/root/children" -Headers $headers
$folderResponse = Invoke-RestMethod -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$targetUpn/drive/root/children" -Headers $headers -Body (@{
        name                                = $timestamp
        folder                              = @{}
        '@microsoft.graph.conflictBehavior' = 'rename'
    } | ConvertTo-Json -Depth 10) -ContentType "application/json"

$folderId = $folderResponse.id

function Upload-To-OneDrive {
    param($filePath, $fileName)
    $uploadUrl = "https://graph.microsoft.com/v1.0/users/$targetUpn/drive/items/$($folderId):/$($fileName):/content"
    Invoke-RestMethod -Uri $uploadUrl -Method PUT -Headers $headers -InFile $filePath -ContentType "application/json"
    Write-Host "📤 Uploaded $fileName"
}

Upload-To-OneDrive $signInFile "signins.json"
Upload-To-OneDrive $auditFile "auditlogs.json"

# Step 6: Send Email From $mailFromUpn To $targetUpn
$emailBody = @"
Sign-in count: $($signIns.Count)
Audit log count for user ($firstUserId): $($auditLogs.Count)
OneDrive folder: $timestamp
"@

$mailPayload = @{
    message         = @{
        subject      = "📊 Office 365 Sign-in & Audit Summary"
        body         = @{
            contentType = "Text"
            content     = $emailBody
        }
        toRecipients = @(
            @{ emailAddress = @{ address = $targetUpn } }
        )
    }
    saveToSentItems = $true
}

Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users/$mailFromUpn/sendMail" -Method POST -Headers $headers -Body ($mailPayload | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json"
Write-Host "📧 Email sent from $mailFromUpn to $targetUpn"
