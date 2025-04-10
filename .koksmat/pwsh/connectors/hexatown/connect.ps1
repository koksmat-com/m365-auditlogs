<# V2.0.8@HEXATOWN 
 
Copyright (C) 2020-2021 Niels Gregers Johansen

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

2.0.8
-----
bug fix:  execute - assuming field in SharePoint list

2.0.7
-----
Error in select SharePoint sites based on $top filter

2.0.6
-----
Added defaults for Init (...$otherOptions)

2.0.5
-----
Change to Exchange Auth and error handling
Bug fixes

2.0.4
-----
removed malicious fields
2.0.3
-----
Missing trailing space

2.0.2
-----
Bug fix

2.0.1
------
Introducting env variable APICAPTURE which will create the file and directory if not present
 
2.0.0
------
Breaking change, to keep authencating to Exchange using
username / password supply option when setting up the context 
connectToExchangeUserNamePassword=$true
1.1.13
-----
- Extended  Send-Hexatown-Mail with a new parameter ContentType defaulting to the original Text value - KUDO lbocak

1.1.12
------
- Included core sharepoint list defintions
- Added Serve function


1.1.11
------
- Supporting SharePoint in Delegate mode

1.1.10
------
- Added test for if module is installed 
- Change to new standard for path location

#>


[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
function FatalError($message) {
    Write-Error $message 
    exit
}
$hexatownAppId = "c5e8d82e-2715-4a89-9eaa-ff8d8ed4b36f"
$domainid = "common"

function Create($hexatown,$apiName,$method,$body) {
    $api = $hexatown.apis.$apiName.$method
    return GraphAPI $hexatown "POST" $api.url $body
}

function Read($hexatown,$apiName, $method) {
    $api = $hexatown.apis.$apiName.$method
    return GraphAPI $hexatown "GET" $api.url
}

function Update($hexatown,$apiName,$method,$id,$body) {
    $api = $hexatown.apis.$apiName.$method
    return GraphAPI $hexatown "PATCH" $api.url $id $body
}

function Delete($hexatown,$apiName,$method,$id) {
    $api = $hexatown.apis.$apiName.$method
    return GraphAPI $hexatown "DELETE" $api.url $id 
}

function List($hexatown,$apiName, $method,$order,$property) {
    $api = $hexatown.apis.$apiName.$method
    if ($null -ne $order){
        return GraphAPIAll $hexatown "GET" $api.url | Sort-Object -Property $property
    }else
    {
        return GraphAPIAll $hexatown "GET" $api.url
    }
    
}

function Parse-JWTtoken {
 
    [cmdletbinding()]
    param([Parameter(Mandatory = $true)][string]$token)
 
    #Validate as per https://tools.ietf.org/html/rfc7519
    #Access and ID tokens are fine, Refresh tokens will not work
    if (!$token.Contains(".") -or !$token.StartsWith("eyJ")) { Write-Error "Invalid token" -ErrorAction Stop }
 
    #Header
    $tokenheader = $token.Split(".")[0].Replace('-', '+').Replace('_', '/')
    #Fix padding as needed, keep adding "=" until string length modulus 4 reaches 0
    while ($tokenheader.Length % 4) { Write-Verbose "Invalid length for a Base-64 char array or string, adding ="; $tokenheader += "=" }
    Write-Verbose "Base64 encoded (padded) header:"
    Write-Verbose $tokenheader
    #Convert from Base64 encoded string to PSObject all at once
    Write-Verbose "Decoded header:"
    [System.Text.Encoding]::ASCII.GetString([system.convert]::FromBase64String($tokenheader)) | ConvertFrom-Json | fl | Out-Default
 
    #Payload
    $tokenPayload = $token.Split(".")[1].Replace('-', '+').Replace('_', '/')
    #Fix padding as needed, keep adding "=" until string length modulus 4 reaches 0
    while ($tokenPayload.Length % 4) { Write-Verbose "Invalid length for a Base-64 char array or string, adding ="; $tokenPayload += "=" }
    Write-Verbose "Base64 encoded (padded) payoad:"
    Write-Verbose $tokenPayload
    #Convert to Byte array
    $tokenByteArray = [System.Convert]::FromBase64String($tokenPayload)
    #Convert to string array
    $tokenArray = [System.Text.Encoding]::ASCII.GetString($tokenByteArray)
    Write-Verbose "Decoded array in JSON format:"
    Write-Verbose $tokenArray
    #Convert from JSON to PSObject
    $tokobj = $tokenArray | ConvertFrom-Json
    Write-Verbose "Decoded Payload:"
    
    return $tokobj
}

function Get-Hexatown-AccessTokenDeviceStep1($client_id, $client_domain) {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/x-www-form-urlencoded")
    $body = "client_id=$client_id&scope=$scope offline_access openid "
    
    $response = Invoke-RestMethod "https://login.microsoftonline.com/$client_domain/oauth2/v2.0/devicecode" -Method 'POST' -Headers $headers -body $body
    return $response
    
}

function Get-Hexatown-AccessTokenDeviceStep2($client_id, $client_domain, $device_code) {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/x-www-form-urlencoded")
    $body = "grant_type=urn:ietf:params:oauth:grant-type:device_code&client_id=$client_id&device_code=$device_code"
    $oldErrorPreference = $ErrorPreference
    $ErrorPreference = 'SilentlyContinue'
    DO
    {
        Sleep -Seconds 1
        
        try
        {
            $response = Invoke-RestMethod "https://login.microsoftonline.com/$client_domain/oauth2/v2.0/token" -Method 'POST' -Headers $headers -body $body        }
        catch [System.Net.WebException],[System.Exception]
        {
        
            $errorDetail =  $Error[0].ErrorDetails.Message | convertfrom-json
            $errorDetail.error
            if ("authorization_pending" -ne $errorDetail.error){
                FatalError $errorDetail.error
            }

        }
        

    } While ($null -eq $response)
    $ErrorPreference = $oldErrorPreference
    return $response
    
}


function Get-Hexatown-AccessTokenDeviceStepRefresh($client_id, $client_domain, $refresh_token) {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/x-www-form-urlencoded")
    $body = "grant_type=refresh_token&client_id=$client_id&scope=$scope offline_access openid&refresh_token=$refresh_token"
    
    try
    {
        $response = Invoke-RestMethod "https://login.microsoftonline.com/$client_domain/oauth2/v2.0/token" -Method 'POST' -Headers $headers -body $body
        
    }
    catch 
    {
        
        $errorData  = ConvertFrom-Json $_ 
        write-host $errorData.error_description -ForegroundColor Yellow
        return $null
    }
    
    return $response
    
}


function Get-Hexatown-Delegate($datapath,$scope){
# $scope = "https%3A//graph.microsoft.com/.default"
# $scope = "Team.ReadBasic.All User.ReadBasic.All "

do
{
    

$refreshTokenFilePath = "$datapath\$($hexatownAppId).refreshtoken.$scope.txt"
if (!(Test-Path $refreshTokenFilePath)) {
    $step1 = Get-Hexatown-AccessTokenDeviceStep1 $hexatownAppId $domainid
    start $step1.verification_uri
    write-host $step1.message
    

    Set-Clipboard -Value $step1.user_code
    $step2 = Get-Hexatown-AccessTokenDeviceStep2 $hexatownAppId $domainid $step1.device_code
    $hexatownDelegate = @{
        token = $step2.access_token
    }
    $accessInfo = Parse-JWTtoken $step2.access_token

    $step2.refresh_token | Out-File -FilePath $refreshTokenFilePath
    return $step2.access_token

}
else {
    
    $refreshToken =  Get-Content $refreshTokenFilePath -Raw
    $step2 = Get-Hexatown-AccessTokenDeviceStepRefresh $hexatownAppId $domainid $refreshToken 

    if ($null -ne $step2){
        $hexatownDelegate = @{
            token = $step2.access_token
        }
        return $step2.access_token
    }else
    {
       Remove-Item $refreshTokenFilePath 
    
    }

}
}
while ($true)
}



function DotEnvConfigure($debug, $path) {

    $loop = $true

    $package = loadFromJSON $path "/../../../package"


    
    $environmentPath = $env:HEXATOWNHOME
    if ($null -eq $environmentPath ) {
        $environmentPath = ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::CommonApplicationData)) 
    }
    $path = "$environmentPath/hexatown.com/$($package.name)"
 
 
    EnsurePath "$environmentPath/hexatown.com"
    if (!(test-path "$environmentPath/hexatown.com/$($package.name)") ) {
        EnsurePath "$environmentPath/hexatown.com/$($package.name)"
        Start-Process "$environmentPath/hexatown.com/$($package.name)"
    }
    
    

    do {
        $filename = "$path\.env"
        if ($debug) {
            write-output "Checking $filename"
        }
        if (Test-Path $filename) {
            if ($debug) {
                write-output "Using $filename"
            }
            $lines = Get-Content $filename
             
            foreach ($line in $lines) {
                    
                $nameValuePair = $line.split("=")
                if ($nameValuePair[0] -ne "") {
                    if ($debug) {
                        write-host "Setting >$($nameValuePair[0])<"
                    }
                    $value = $nameValuePair[1]
                    
                    for ($i = 2; $i -lt $nameValuePair.Count; $i++) {
                        $value += "="
                        $value += $nameValuePair[$i]
                    }

                    if ($debug) {
                        write-host "To >$value<"
                    }    
                    [System.Environment]::SetEnvironmentVariable($nameValuePair[0], $value)
                }
            }
    
            $loop = $false
        }
        else {
            $lastBackslash = $path.LastIndexOf("\")
            if ($lastBackslash -lt 4) {
                $loop = $false
                if ($debug) {
                    write-output "Didn't find any .env file  "
                }
            }
            else {
                $path = $path.Substring(0, $lastBackslash)
            }
        }
    
    } while ($loop)
    
}
    

function GetAccessToken($client_id, $client_secret, $client_domain) {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/x-www-form-urlencoded")
    $body = "grant_type=client_credentials&client_id=$client_id&client_secret=$client_secret&scope=https%3A//graph.microsoft.com/.default"
    
    $response = Invoke-RestMethod "https://login.microsoftonline.com/$client_domain/oauth2/v2.0/token" -Method 'POST' -Headers $headers -body $body
    return $response.access_token
    
}
function ConnectExchange($username, $secret) {
    write-output "Connecting to Exchange Online"
    $code = ConvertTo-SecureString $secret -AsPlainText -Force
    $psCred = New-Object System.Management.Automation.PSCredential -ArgumentList ($username, $code)
    
    
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $psCred -Authentication Basic -AllowRedirection
    Import-PSSession $Session -DisableNameChecking 
    return $Session
    
}
    
function ConnectExchange2($appid, $token,$ignoreErrors) {

    
    
    if ($env:EXCHCERTIFICATEPATH -eq ""){
       FatalError 'Missing $env:EXCHCERTIFICATEPATH'
    }
    if ($env:EXCHCERTIFICATEPASSWORD -eq ""){
       FatalError 'Missing $env:EXCHCERTIFICATEPASSWORD'
    }
    if ($env:EXCHORGANIZATION -eq ""){
       FatalError 'Missing $env:EXCHORGANIZATION'
    }
    if ($env:EXCHAPPID -eq ""){
       FatalError 'Missing $env:EXCHAPPID'
    }

    $errorAction =[System.Management.Automation.ActionPreference]::Continue
    if ($ignoreErrors){
        $errorAction =[System.Management.Automation.ActionPreference]::SilentlyContinue
    }

    
    $Session = Connect-ExchangeOnline -CertificateFilePath $env:EXCHCERTIFICATEPATH -CertificatePassword (ConvertTo-SecureString -String $env:EXCHCERTIFICATEPASSWORD -AsPlainText -Force) -AppID $env:EXCHAPPID -Organization $env:EXCHORGANIZATION -ShowBanner:$false   -ErrorAction SilentlyContinue # $errorAction
    

    return $Session
    
}
    
function CreateAlias($name) {
    return $name.ToLower().Replace(" ", "-").Replace(" ", "-").Replace(" ", "-").Replace(" ", "-").Replace(" ", "-").Replace(" ", "-")
}

function EnsurePath($path) {

    If (!(test-path $path)) {
        New-Item -ItemType Directory -Force -Path $path
    }
}

function RealErrorCount() {
    $c = 0
    foreach ($e in $Error) {
        $m = $e.ToString()
        if (!$m.Contains("__Invoke-ReadLineForEditorServices")) {
            $c++
        }
    }
    return $c 
}
function LastError() {
    $m = ""
    foreach ($e in $Error) {
        $m += ($e.ToString().substring(0, 200) + "`n")

    }
    return $m    
}

function isMember($members, $roomSmtpAddress) {
    $found = $false
    foreach ($member in $members) {
        if ($members.PrimarySmtpAddress -eq $roomSmtpAddress) {
            $found = $true
        }
    }
    return $found
}


function LogToSharePoint($token, $site , $title, $status, $system, $subSystem, $reference, $Quantity, $details) {
    $myHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $myHeaders.Add("Content-Type", "application/json")
    $myHeaders.Add("Accept", "application/json")
    $myHeaders.Add("Authorization", "Bearer $token" )
    $hostName = $env:COMPUTERNAME
    $details = $details -replace """", "\"""
    $body = "{
        `n    `"fields`": {
        `n        `"Title`": `"$title`",
        `n        `"Host`": `"$hostName`",
        `n        `"Status`": `"$status`",
        `n        `"System`": `"$system`",
        `n        `"SubSystem`": `"$subSystem`",
        `n        `"SystemReference`":`"$reference`",
        `n        `"Quantity`": $Quantity,
        `n        `"Details`": `"$details`"
        `n    }
        `n}"

    # write-output $body 
    #    Out-File -FilePath "$PSScriptRoot\error.json" -InputObject $body
    $url = ($site + '/Lists/Log/items/')
  
    $dummy = Invoke-RestMethod $url -Method 'POST' -Headers $myHeaders -Body $body 
    # return $null -eq $dummy
}

function Write-Hexatown-Log($hexatown,$title, $status, $system, $subSystem, $reference, $Quantity, $details){
 LogToSharePoint $hexatown.token  $hexatown.site $title $status $system $subSystem $reference  $Quantity  $details
}

function LogChange($hexatown , $title, $area, $method , $reference) {
    LogToSharePoint $hexatown.token $hexatown.site $title "OK" $area $method $reference 0 "."
}

function ReportErrors($token, $site) {
    if ($Error.Count -gt 0) {
        $errorMessages = ""
        foreach ($errorMessage in $Error) {
            if (($null -ne $errorMessage.InvocationInfo) -and ($errorMessage.InvocationInfo.ScriptLineNumber)) {
                $errorMessages += ("Line: " + $errorMessage.InvocationInfo.ScriptLineNumber + " "  )    
            }

            $errorMessages += $errorMessage.ToString() 
            $errorMessages += "`n"

        }

        LogToSharePoint $token $site "Error in PowerShell" "Error" "PowerShell"  $MyInvocation.MyCommand $null 0 $errorMessages
    }



    function ConnectExchange($username, $secret) {
        $code = ConvertTo-SecureString $secret -AsPlainText -Force
        $psCred = New-Object System.Management.Automation.PSCredential -ArgumentList ($username, $code)
    
    
        $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $psCred -Authentication Basic -AllowRedirection
        Import-PSSession $Session -DisableNameChecking 
        return $Session
    
    }
    
}


function FindSiteByUrl($token, $siteUrl) {
    $Xheaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Xheaders.Add("Content-Type", "application/json")
    $Xheaders.Add("Prefer", "apiversion=2.1") ## Not compatibel when reading items from SharePointed fields 
    $Xheaders.Add("Authorization", "Bearer $token" )

    $url = 'https://graph.microsoft.com/v1.0/sites/root'
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
   

    return  ( "https://graph.microsoft.com/v1.0/sites/" + $site.id)
}

function GraphAPI($hexatown, $method, $url, $body,$ignoreError) {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    $headers.Add("Accept", "application/json")
    $headers.Add("Authorization", "Bearer $($hexatown.token)" )
    
    
    $errorCount = $error.Count
    $CurrentErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $result = Invoke-RestMethod ($url) -Method $method -Headers $headers -Body $body 
    
    $ErrorActionPreference = $CurrentErrorActionPreference
    if (!$ignoreError -and $errorCount -ne $error.Count) {
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
function GraphAPIAll($hexatown, $method, $url) {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    $headers.Add("Accept", "application/json")
    $headers.Add("Authorization", "Bearer $($hexatown.token)" )
    
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


function SharePointRead($hexatown, $path) {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    $headers.Add("Accept", "application/json")
    $headers.Add("Authorization", "Bearer $($hexatown.token)" )
    $url = $hexatown.site + $path
    $errorCount = $error.Count
    $result = Invoke-RestMethod ($url) -Method 'GET' -Headers $headers 
    if ($errorCount -ne $error.Count) {
        Write-Error $url
    }

    $data = $result.value
    $counter = 0
    while ($result.'@odata.nextLink') {
        Write-Progress -Activity "Reading from SharePoint $path" -Status "$counter Items Read" 

        if ($hexatown.verbose) {
            write-output "SharePointRead $($result.'@odata.nextLink')"
        }
        $result = Invoke-RestMethod ($result.'@odata.nextLink') -Method 'GET' -Headers $headers 
        $data += $result.value
        $counter += $result.value.Count
        
    }

    return $data
}



<#
 https://stackoverflow.com/questions/49169917/microsoft-graph-honornonindexedquerieswarningmayfailrandomly-error-when-filterin  
 Prefer: allowthrottleablequeries
#>
function SharePointReadThrottleableQuery  ($hexatown, $path) {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    $headers.Add("Accept", "application/json")
    $headers.Add("Prefer", "allowthrottleablequeries")
    $headers.Add("Authorization", "Bearer $($hexatown.token)" )
    $url = $hexatown.site + $path
    $errorCount = $error.Count
    $result = Invoke-RestMethod ($url) -Method 'GET' -Headers $headers 
    if ($errorCount -ne $error.Count) {
        Write-Error $url
    }

    $data = $result.value
    $counter = 0
    while ($result.'@odata.nextLink') {
        Write-Progress -Activity "Reading from SharePoint $path" -Status "$counter Items Read" 

        if ($hexatown.verbose) {
            write-output "SharePointRead $($result.'@odata.nextLink')"
        }
        $result = Invoke-RestMethod ($result.'@odata.nextLink') -Method 'GET' -Headers $headers 
        $data += $result.value
        $counter += $result.value.Count
        
    }

    return $data
}

function GetSharePointListItem($token, $site, $listName, $listItemId ) {
    # https://stackoverflow.com/questions/49238355/whats-the-post-body-to-create-multichoice-fields-in-sharepoint-online-using-gra
    $myHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $myHeaders.Add("Content-Type", "application/json; charset=utf-8")
    $myHeaders.Add("Accept", "application/json")
    $myHeaders.Add("Authorization", "Bearer $token" )
    $hostName = $env:COMPUTERNAME
    $details = $details -replace """", "\"""
        
    # write-output $body 
    #    Out-File -FilePath "$PSScriptRoot\error.json" -InputObject $body
    $url = $site + "/Lists/$listName/items/$listItemId" 
    # write-output $url
    $result = Invoke-RestMethod $url -Method 'GET' -Headers $myHeaders  
    return  (RemoveStandardSharePointProperties $result)
     
    # return $null -eq $dummy
}
function PatchSharePointListItem($token, $site, $listName, $listItemId, $body ) {
    # https://stackoverflow.com/questions/49238355/whats-the-post-body-to-create-multichoice-fields-in-sharepoint-online-using-gra
    $myHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $myHeaders.Add("Content-Type", "application/json; charset=utf-8")
    $myHeaders.Add("Accept", "application/json")
    $myHeaders.Add("Authorization", "Bearer $token" )
    $hostName = $env:COMPUTERNAME
    $details = $details -replace """", "\"""
        
    # write-output $body 
    #    Out-File -FilePath "$PSScriptRoot\error.json" -InputObject $body
    $url = ($site + "/Lists/$listName/items/$listItemId")
    # write-output $url
    return Invoke-RestMethod $url -Method 'PATCH' -Headers $myHeaders -Body ([System.Text.Encoding]::UTF8.GetBytes($body) )
    # return $null -eq $dummy
}

function DeleteSharePointListItem($token, $site, $listName, $listItemId ) {
    # https://stackoverflow.com/questions/49238355/whats-the-post-body-to-create-multichoice-fields-in-sharepoint-online-using-gra
    $myHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $myHeaders.Add("Content-Type", "application/json")
    $myHeaders.Add("Accept", "application/json")
    $myHeaders.Add("Authorization", "Bearer $token" )
    $hostName = $env:COMPUTERNAME
    $details = $details -replace """", "\"""
        
    # write-output $body 
    #    Out-File -FilePath "$PSScriptRoot\error.json" -InputObject $body
    $url = ($site + "/Lists/$listName/items/$listItemId")
    # write-output $url
    return Invoke-RestMethod $url -Method 'DELETE' -Headers $myHeaders 
    # return $null -eq $dummy
}
       
function PostSharePointListItem($token, $site, $listName, $body ) {
    # https://stackoverflow.com/questions/49238355/whats-the-post-body-to-create-multichoice-fields-in-sharepoint-online-using-gra
    $myHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $myHeaders.Add("Content-Type", "application/json; charset=utf-8")
    $myHeaders.Add("Accept", "application/json")
    $myHeaders.Add("Authorization", "Bearer $token" )
    
    $url = ($site + "/Lists/$listName/items")
    $result = Invoke-RestMethod $url -Method 'POST' -Headers $myHeaders -Body ([System.Text.Encoding]::UTF8.GetBytes($body) )
    return $result
    # write-output "."
    # return $null -eq $dummy
}

        
function SharePointLookup($hexatown, $path) {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    $headers.Add("Accept", "application/json")
    $headers.Add("Authorization", "Bearer $($hexatown.token)" )
    $url = $hexatown.site + $path
    if ($hexatown.verbose) {
        write-output "SharePointLookup $url"
    }
    $result = Invoke-RestMethod ($url) -Method 'GET' -Headers $headers 
    return $result

}
function loadFromJSON($directory, $file) {
    
    $data = Get-Content "$directory\$file.json" -Encoding UTF8 | Out-String | ConvertFrom-Json
    if ("System.Object[]" -ne $data.GetType()) {
        $data = @($data)
    }
    
    return $data
}

function downloadLists($hexatown, $schema, $lists) {
    $counter = 0
    
    foreach ($list in $lists) {
        

        Write-Progress -Activity "Downloading  $($lists.Count) list from SharePoint" -Status "$counter Read" -CurrentOperation "Lists $list"
        $listName = $schema | Select -ExpandProperty $list.Name
        $items = (SharePointRead  $hexatown ('/Lists/' + $listName + '/items?$expand=fields'))

        $itemFields = @()

        foreach ($item in $items) {
            if ($item.fields) {
                $itemFields += $item.fields
            }
            # $lookup.Add("$($list.Name):$($item.id)",$item)
        }


        $counter += $items.Count
        ConvertTo-Json -InputObject $itemFields  -Depth 10 | Out-File "$($hexatown.datapath)\$($list.Name).sharepoint.json" 
    }
    Write-Progress -Completed  -Activity "done"
}


function getList($hexatown, $listName) {

    Write-Progress -Activity "Downloading  $listName from SharePoint" 
   
    $items = (SharePointRead  $hexatown ('/Lists/' + $listName + '/items?$expand=fields'))

    $itemFields = @()

    foreach ($item in $items) {
        if ($item.fields) {
            $itemFields += $item.fields
        }
    }

    return $itemFields 
}

function loadLists($hexatown, $schema, $lists) {
    $lookup = @{}
    foreach ($list in $lists) {
        
        $items = loadFromJSON $hexatown.datapath "$($list.Name).sharepoint" 

        write-output "$($list.Name) $($items.Count) items"
        foreach ($item in $items) {
            $lookup.Add("$($list.Name)__$($item.id)", $item)
        }

    }
    return $lookup
}


function Init ($invocation, $requireExchange, $delegated,$scope,$otherOptions) {

    if ($null -eq $otherOptions){
        $otherOptions = @{
connectToSharePoint = $true
                         SkipTranscript = $false
                        }
    }

    $scriptName = $invocation.MyCommand.Name
    $path = Split-Path $invocation.MyCommand.Path
    DotEnvConfigure $false $path

    if ($null -eq $env:DEVELOP) {
        $WarningPreference = 'SilentlyContinue'
        $DebugPreference = 'SilentlyContinue'
        $ProgressPreference = 'SilentlyContinue'
        $VerbosePreference = 'SilentlyContinue'
    }

    $package = loadFromJSON $path "/../../../package"
    $srcPath = (Resolve-Path ($path + "\..\..\..")).Path
    
    
    $environmentPath = $env:HEXATOWNHOME
    if ($null -eq $environmentPath ) {
        $environmentPath = ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::CommonApplicationData)) 
    }
    

    $homePath = (Resolve-Path ("$environmentPath/hexatown.com/$($package.name)"))

    $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
   
    $tenantDomain = $ENV:AADDOMAIN
    if ($null -eq $tenantDomain) {
        $tenantDomain = "hexatown.com"
        Write-Host "Environment name not set - defaulting to $tenantDomain" -ForegroundColor Yellow
        
    }

    
    EnsurePath "$homePath\logs"

    $logPath = "$homePath\logs\$tenantDomain"
    EnsurePath $logPath

    $metadataPath = "$srcPath\.metadata"
    EnsurePath $metadataPath


    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd-hh")
    if (!$otherOptions.SkipTranscript) {
        Start-Transcript -Path "$logPath\$scriptName-$timestamp.log" | Out-Null
    }

    EnsurePath "$homePath\data"

    $dataPath = "$homePath\data" #TODO: Make data path tenant aware
    $dataPath = "$datapath\$tenantDomain" #TODO: Make data path tenant aware
    EnsurePath $dataPath


    $Error.Clear() 
 

    $dev = $env:DEBUG
    $hasSharePoint = $false
    if (!$delegated){


    $token = GetAccessToken $env:APPCLIENT_ID $env:APPCLIENT_SECRET $env:APPCLIENT_DOMAIN
     if ($otherOptions.connectToSharePoint){
        $site = FindSiteByUrl $token $env:SITEURL
        if ($env:HEXATOWNURL) {
            $hexatownsite = FindSiteByUrl $token $env:HEXATOWNURL
        }
    
    
        if ($null -eq $site) {
            Write-Warning "Not able for find site - is \$env:SITEURL defined?"
            exit
        }
        $hasSharePoint = $true
    }
    }else{
    if ($null -eq $scope){
        $scope = "Team.ReadBasic.All User.ReadBasic.All "
    }
    
    $token = Get-Hexatown-Delegate $dataPath $scope
    if ($otherOptions.connectToSharePoint){
        $site = FindSiteByUrl $token $env:SITEURL
        if ($env:HEXATOWNURL) {
            $hexatownsite = FindSiteByUrl $token $env:HEXATOWNURL
        }
    
    
        if ($null -eq $site) {
            Write-Warning "Not able for find site - is \$env:SITEURL defined?"
            exit
        }
        $hasSharePoint = $true
    }
    
    }

    $schema = loadFromJSON $path ".schema"

    $hexatown = @{
        $logPath     = "$logPath\$tenantDomain"
        domain       = $tenantDomain
        IsDev        = $dev
        site         = $site
        datapath     = $dataPath
        metadatapath = $metadataPath
        logpath      = $logPath
        token        = $token
        verbose      = $env:VERBOSE
        session      = $session
        siteUrl      = $env:SITEURL
        appId        = $env:APPCLIENT_ID
        appSecret    = $env:APPCLIENT_SECRET 
        appDomain    = $env:APPCLIENT_DOMAIN
        hexatown     = $hexatownsite
        schema       = $schema
        isDelegate   = $delegated
        hasSharePoint= $hasSharePoint
        hasExchange  = $requireExchange
        isExchangeConnected = $false
        SkipTranscript = $otherOptions.SkipTranscript
        apis         = @{
                        my = @{
                            self =   @{
                                url = "https://graph.microsoft.com/v1.0/me"
                            }
                            teams = @{
                                url = "https://graph.microsoft.com/v1.0/me/joinedTeams"
                            }
                        }

                        }
    }


    if ($requireExchange) {
        # https://www.quadrotech-it.com/blog/certificate-based-authentication-for-exchange-online-remote-powershell/
    
        $moduleRoot = Join-Path $path "..\..\..\modules"
        $moduleName = "ExchangeOnlineManagement"
        $modulePath = join-path $moduleRoot $moduleName
        if (!(Test-Path $modulePath)){
            FatalError "Module '$moduleName' not installed" 
            
        }
        Import-Module -Name $modulePath -DisableNameChecking
    
            
            if ($true -eq $otherOptions.connectToExchangeUserNamePassword){
                $session = ConnectExchange $env:AADUSER $env:AADPASSWORD
            }else{
            
                
try 
{ $var = Get-Mailbox
$hexatown.isExchangeConnected = $true
} 

catch # [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] 
{ 
 
 ConnectExchange2 $env:APPCLIENT_ID $token $otherOptions.IgnoreErrors
  }

                        

                
            }     
            
    
        }
    
    return $hexatown

}
    
function Start-Hexatown($invocation,$scope,$otherOptions){

return Init $invocation $false $true $scope $otherOptions
}

function Start-HexatownApp($invocation,$otherOptions){

return Init $invocation $false $false $null $otherOptions  
}

function Start-HexatownAppWithExchange($invocation,$otherOptions){

return Init $invocation $true $false $null $otherOptions
}

function Done($hexatown) {

    Write-Progress -Completed  -Activity "done"
    if (!$hexatown.IsDev) {
        write-output "Closing sessions"
        get-pssession | Remove-PSSession
        if ($hexatown.hasExchange){
            Disconnect-ExchangeOnline -Confirm:$false
        }
    }
    if ($hexatown.hasSharePoint){
        ReportErrors $hexatown.token $hexatown.site
    }
    if (!$hexatown.SkipTranscript){
        Stop-Transcript
    }
}

function Stop-Hexatown($hexatown){
    Done $hexatown
}


function Me(){
    return Init $MyInvocation  $false $true

}

function ShowState ($text) {
    write-output $text ## for transcript log
    Write-Progress -Activity $text
    
}


function CreateDictionary($hexatown, $dataset, $key) {
    $lookupGroups = @{}

    $indexColumn = "Title"
    if ($null -ne $key) {
        $indexColumn = $key
    
    }
        
    $items = loadFromJSON $hexatown.datapath $dataset


    foreach ($item in $items) {
        if (   $null -ne $item.$indexColumn -and !$lookupGroups.ContainsKey($item.$indexColumn) ) {
            $lookupGroups.Add($item.$indexColumn, $item)
        }
    }

    return $lookupGroups
}

function run($script) {
    write-output "Running $script"
    & "$PSScriptRoot\$script.ps1"
}

function getHash($text) {
    
    $stringAsStream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.StreamWriter]::new($stringAsStream)
    $writer.write($text)
    $writer.Flush()
    $stringAsStream.Position = 0
    return (Get-FileHash -InputStream $stringAsStream | Select-Object Hash).Hash
}


function getReference($dictionary, $key) {
    if ($null -eq $key) {
        return $null
    }
    return $dictionary.$key
}

function loadCrossRef($dataset, $key) {
    if ($null -eq $key) {
        return $null
    }
    return  $dataset.$key
}

function getProperty($bags, $name, $defaultValue) {

    if ($null -eq $bags.$name) {
        if ($null -eq $defaultValue ) {
            Write-Error "Missing property value for $name"
            Done $hexatown
            Exit
        }
        return $defaultValue
    }

    return $bags.$name.Value
   
}



function RemoveUnwantedProperties($item, $wantedFields) {
    $fieldsToKeep = @{}
    foreach ($wantedField in $wantedFields) {
        $fieldsToKeep.Add($wantedField, $wantedField  )
    }

    $fields = $item | Get-Member -MemberType NoteProperty | select Name

    

    foreach ($field in $fields) {
        if (!$fieldsToKeep.ContainsKey($field.Name)) {
            $item.PSObject.Properties.Remove($field.Name)
        }
    }

    return $item
}

    


function RemoveStandardSharePointElements($fields) {

$standardSharePointFields = @("@odata.etag", 
        "id",
        "Title",
        "ContentType",
        "Modified",
        "Created",
        "_UIVersionString",
        "Attachments",
        "Edit",
        "LinkTitleNoMenu",
        "LinkTitle",
        "ItemChildCount",
        "FolderChildCount",
        "contentType",
        "modified",
        "created",
         "Title",
        "Author",
        "AppAuthor",
        "Editor",
        "AppEditor",
        "_UIVersionString",
        "attachments",
        "edit",
        "linkTitleNoMenu",
        "linkTitle",
        "itemChildCount",
        "folderChildCount",
        "ComplianceAssetId"
        "_ComplianceFlags",
        "_ComplianceTag",
        "_ComplianceTagWrittenTime",
        "_ComplianceTagUserId",
        "DocIcon",
        "_IsRecord")
    $newFields = @()    
    foreach ($field in $fields)
    {
        $remove = $false
        foreach ($standardSharePointField in $standardSharePointFields) {
            if ($field.name -eq $standardSharePointField){
                $remove = $true
            }
        }
        if (!$remove){
        $newFields += $field
}
    }
    return $newFields

}

function RemoveStandardSharePointProperties($item) {
    $standardSharePointFields = @("@odata.etag", 
        #"id", << This field shall not be removed !        
        "ContentType",
        "Modified",
        "Created",
        "AuthorLookupId",
        "AppAuthorLookupId",
        "EditorLookupId",
        "AppEditorLookupId",
        "_UIVersionString",
        "Attachments",
        "Edit",
        "LinkTitleNoMenu",
        "LinkTitle",
        "ItemChildCount",
        "FolderChildCount",
        "contentType",
        "modified",
        "created",
        "authorLookupId",
        "appAuthorLookupId",
        "editorLookupId",
        "appEditorLookupId",
        "_UIVersionString",
        "attachments",
        "edit",
        "linkTitleNoMenu",
        "linkTitle",
        "itemChildCount",
        "folderChildCount",

        "_ComplianceFlags",
        "_ComplianceTag",
        "_ComplianceTagWrittenTime",
        "_ComplianceTagUserId")


    foreach ($field in $standardSharePointFields) {
        $item.PSObject.Properties.Remove($field)
    }
    return $item

}

function CreateSlaveDictionary($hexatown, $dataset, $fields) {
    $lookupGroups = @{}
        
    $items = loadFromJSON $hexatown.datapath $dataset


    foreach ($item in $items) {
        if (   $null -ne $item.Title -and !$lookupGroups.ContainsKey($item.Title) ) {
            $cleanedItem = RemoveUnwantedProperties $item $fields
            $lookupGroups.Add($item.Title, $cleanedItem)
        }
    }

    return $lookupGroups
}

function CreateMasterDictionary($hexatown, $dataset, $fields) {
    $lookupGroups = @{}
        
    $items = loadFromJSON $hexatown.datapath $dataset


    foreach ($item in $items) {
        if (   $null -ne $item.Title -and !$lookupGroups.ContainsKey($item.Title) ) {
            $cleanedItem = RemoveStandardSharePointProperties $item $fields
            # $cleanedItem = RemoveStandardSharePointProperties cleanedItem
            if ($null -ne $item.Title) {
                $lookupGroups.Add($item.Title, $cleanedItem)
            }
        }
    }

    return $lookupGroups
}

function buildDelta($hexatown, $table, $fields) {
    ShowState "Building delta for $table" 
    $masterItems = CreateMasterDictionary $hexatown "$table.sharepoint"
    $slaveItems = CreateSlaveDictionary $hexatown "$table.slave" $fields
    $delta = buildDelta2 $masterItems $slaveItems $fields

    ConvertTo-Json -InputObject $delta  -Depth 10 | Out-File "$($hexatown.datapath)\$table.delta.json" 

}

function buildDelta2($masterItems, $slaveItems, $fields) {
    ShowState "Building delta" 
    

    $delta = @{
        newItems     = @()
        deletedItems = @()
        changedItems = @()
    }

    foreach ($masterItemKey in $masterItems.keys) {
        if (!$slaveItems.containsKey($masterItemKey)) {
            $delta.newItems += RemoveStandardSharePointProperties $masterItems[$masterItemKey]
        }
    }
    
    foreach ($slaveItemKey in $slaveItems.keys) {
        if (!$masterItems.containsKey($slaveItemKey)) {
            $delta.deletedItems += $slaveItems[$slaveItemKey]
        }
    }

    foreach ($masterItemKey in $masterItems.keys) {

        if ($slaveItems.containsKey($masterItemKey)) {
            $masterItem = RemoveStandardSharePointProperties $masterItems[$masterItemKey]
            $slaveItem = $slaveItems[$masterItemKey]

            $changes = @()
            $hasChanges = $false


            foreach ($field in $fields) {
                $masterField = $masterItem.$field | ConvertTo-Json -Depth 10
                $slaveField = $slaveItem.$field | ConvertTo-Json -Depth 10

                if ($masterField -ne $slaveField ) {
                
                    $hasChanges = $true
                    $changes += ${
                    field  = $field
                    master =  $masterField 
                    slave =  $slaveField
                } | ConvertTo-Json
                }
            }


            if ($hasChanges ) {
                           

                $delta.changedItems += @{
                    slave  = $slaveItem
                    master = $masterItem
                }
            }
            
            
        }
    }
 
    

    return $delta

}




function getListCount($hexatown, $listName, $filter) {

    Write-Progress -Activity "Counting $listName from SharePoint" 

    $items = (SharePointReadThrottleableQuery  $hexatown ('/Lists/' + $listName + '/items/?$expand=fields&' + $filter))
    
    return $items.Count
}



function DomainFromEmail($email) {
    if ($null -eq $email) {
        return ""
    }
    $at = $email.indexOf("@");
    if ($at -gt 0) {
        return $email.Substring($at + 1)
    }
    else {
        return ""
    
    }
    
}

function RefreshSharePointList ($hexatown ) {
    $schema = loadFromJSON $PSScriptRoot ".schema"
    $lists = $schema.lists | Get-Member -MemberType  NoteProperty | select Name 

    ShowState "Refreshing copy of SharePoint lists" 
    downloadLists $hexatown $schema.lists  $lists
}

function Initialize-Hexatown-Lists($hexatown) {
    return RefreshSharePointList $hexatown
}


# https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands?view=powershell-7.1 
function Send-Hexatown-Mail($hexatown, $from, $to, $subject, $messageBody,$contentType="Text") {
    $body = @{
        message = @{
            subject      = $subject
            body         = @{
                contentType = $contentType
                content     = $messageBody
            }
            toRecipients = @(
                @{
                    emailAddress = @{
                        address = $to
                    }
                }
          
            )
        }
    } | ConvertTo-Json -Depth 10
    
    
    GraphAPI $hexatown POST "https://graph.microsoft.com/v1.0/users/$from/sendMail" $body
    
}
    


function Compare-Hexatown-Lists($hexatown, $map) {
    ShowState "Loading Master" | Out-Null
    $masters = CreateDictionary $hexatown "$($map.list).master" 
    ShowState "Loading Slave" | Out-Null
    $slave = CreateDictionary $hexatown "$($map.list).slave" 
        
    $delta = buildDelta2  $slave  $masters $map.fields
        
    return $delta
        
}


function Sync-Hexatown-List($hexatown, $listname, $delta) {
    ShowState "Syncronzing List $listname" | Out-Null
    foreach ($item in $delta.newItems) {
        
        $body = @{fields = $item } | ConvertTo-Json
        DeleteSharePointListItem $hexatown.token $hexatown.site $listname  $item.Id
    }
    
    foreach ($item in $delta.deletedItems) {
        $item.PSObject.Properties.Remove("Id")
        $body = @{fields = $item } | ConvertTo-Json
        PostSharePointListItem $hexatown.token $hexatown.site $listname $body
    }
    
    foreach ($item in $delta.changedItems) {
        $id = $item.master.Id
        $item.slave.PSObject.Properties.Remove("Id")
        $body = @{fields = $item.slave } | ConvertTo-Json
        PatchSharePointListItem $hexatown.token $hexatown.site $listname $id $body
    }
}

function Update-Hexatown-ComparisonSource($hexatown,$map,$source){
$inputData = loadFromJSON $hexatown.datapath $map.$source.file
$sourceMap = $map.$source

$counter = 0
$result = @()
foreach ($input in $inputData) { 
    $percent = [int]($counter / $inputData.Count * 100)
    Write-Progress -Activity "Reading $($sourceMap.file)" -Status "$counter Read" -PercentComplete $percent
        $item = @{}
        $item.Title = $input.($sourceMap.primaryKey)
        $item.Id    = $input.($sourceMap.id)
        
        foreach ($field in $sourceMap.fields) {

        
                $split = $field.from.Split(".")
                if ($split.Count -gt 1){
                $array = @()
                    foreach ($value in $input.($split[0])) {
                        $element = $value.($split[1])
                        $array += $element
                    }

                $item.($field.to) = $array
                }
                else{
                $item.($field.to) = $input.($field.from)
                }
                if ($field.typename){
                    $item.($field.typename) =$field.typevalue
                }
        }
        
        $result +=  $item
        $counter ++
}
ConvertTo-Json -InputObject $result   -Depth 10 | Out-File "$($hexatown.datapath)\$($map.list).$source.json" 

}

    

function execute($hexatown ,$list,$script){
    $schema = loadFromJSON $PSScriptRoot ".schema"
    $filter = "fields/Processed ne 1"
    $items = SharePointReadThrottleableQuery  $hexatown ('/Lists/' + $schema.lists.$list + '/items/?$expand=fields&$filter=' + $filter)

    foreach ($item in $items)
    {
        $request = RemoveStandardSharePointProperties $item.fields
        $errorMessage =$null
        $response=$null
        try
        {
            $response = Invoke-Command -ScriptBlock $script | convertto-json 
            $ResponseCode = 200
        }
        catch 
        {
            $response  =   $psitem.Exception.Message
            $ResponseCode = 500
        }
        
     

$body = @{fields = @{
                      Processed = $true
                      # ResponseCode = $ResponseCode
     #                 Error = $errorMessage
                      Response = $response 
                     } 
} | ConvertTo-Json
        PatchSharePointListItem $hexatown.token $hexatown.site $schema.lists.$list $item.id $body | Out-Null
    }
}

function GetPayload($request){

try
{
     $payload = ConvertFrom-Json -InputObject $request.Request    
}

catch 
{
    $errorMessage = $psitem.Exception.Message
    $payload = @{}
}
return $payload,$errorMessage

}

function Serve() {

param(
$hexatown,
$minutes = 30,
$callBacks = @{}
)

try
{

    $StartDate=(GET-DATE)
    $StartDateMinute=(GET-DATE)
    $TotalMinutes = 0
    $requestListName = "Hexatown Requests"
    

    
    
    write-host "Serve process will run for $minutes minutes"
    $done = $false
    do
    {
        
    $filter = "fields/Processed ne 1"
    $items = SharePointReadThrottleableQuery  $hexatown ("/Lists/$requestListName/items/?`$expand=fields&`$filter=$filter&`$orderby=id")

    foreach ($item in $items)
    {
        $request = RemoveStandardSharePointProperties $item.fields
        write-host $item.id $path $method $payload.title $requestor  
        $parsedRequest = (GetPayload $request)
        $payLoad = $parsedRequest[0]
        if ($null-ne $parsedRequest[1]){
            $ResponseCode = 400
            $responseData = $parsedRequest[1]
            $responseJSON = $responseData | convertto-json -Depth 10
            # $responseCSV = $responseData | ConvertTo-Csv -Delimiter "|" | Convertto-Json 

        }
        else {        
        $requestor = $item.createdBy.user
        $errorMessage =$null
        $response=$null
        
        try
        {
        
            $path = $request.Path
            $method = $request.Method
            if ($ENV:APICAPTURE){
            if (!(test-path "$PSScriptRoot/../../apis$path/$method.ps1")){
                EnsurePath "$PSScriptRoot/../../apis$path"
                $scriptText = @"
param (`$hexatown,`$request,`$requestor)
&`"`$PSScriptRoot\..\..\actions\***THE SCRIPT TO USE***.ps1" `
`$hexatown `

"@        

    $requestFields = $payload | Get-Member -MemberType  NoteProperty | Select Name
    foreach ($field in $requestFields)
    {
        $scriptText += "`$request.'$($field.Name)'`` `n"
    }
    
            Out-File "$PSScriptRoot/../../apis$path/$method.ps1" -InputObject  $scriptText 
            
            }
            
            }
          
            if (!(test-path "$PSScriptRoot/../../apis$path/$method.ps1")) {
                $responseData = "apis$path/$method not found"
                $ResponseCode = 401
            }else
            {

                if (!(test-path "$PSScriptRoot/../../apis$path/$method.sample.json")) {
                    $requestProperties = $payload | Get-Member -MemberType  NoteProperty | Select Name, Definition
                    ConvertTo-Json -InputObject $requestProperties  -Depth 10 | Out-File "$PSScriptRoot/../../apis$path/$method.sample.json" 

                }
                if (!(test-path "$PSScriptRoot/../../apis$path/$method.fields.json")) {

                    $requestFields = $payload | Get-Member -MemberType  NoteProperty | Select Name
                    ConvertTo-Json -InputObject $requestFields  -Depth 10 | Out-File "$PSScriptRoot/../../apis$path/$method.fields.json" 
                }

                $responseData = & "$PSScriptRoot/../../apis/$path/$method.ps1" $hexatown $payload $requestor
                
                
                $ResponseCode = 200
                
            }        
        
        }
        catch 
        {
            $responseData  = $psitem.Exception.Message
            $ResponseCode = 500
        }
        finally {
            $responseJSON = $responseData | convertto-json -Depth 10
            #$responseCSV = $responseData | ConvertTo-Csv -Delimiter "|" | Convertto-Json 
        }
        if ($null -eq $responseData){
            
            $responseJSON = ""
            $responseCSV = ""
        }
        }

     
$body = @{fields = @{
                      Processed = $true
                      Responsecode = $ResponseCode
                      Response = $responseJSON
                      #ResponseCSV = $responseCSV 
                     } 
} | ConvertTo-Json

        PatchSharePointListItem $hexatown.token $hexatown.site $requestListName $item.id $body | Out-Null
        Write-Host "Response code" $responseCode
    }

        Start-Sleep -Seconds 1
        $elapsed =  New-TimeSpan -Start $StartDate -End (GET-DATE)

        $elapsedMinute =  New-TimeSpan -Start $StartDateMinute -End (GET-DATE)

        if ($elapsedMinute.TotalMinutes -ge 1){
            $TotalMinutes++
            Write-host "One minute passed, $TotalMinutes total minutes " -ForegroundColor Gray
            
            $StartDateMinute=(GET-DATE)
        }


        if ($elapsed.TotalMinutes -gt $minutes){
            Write-host "Processes time of $minutes passed" -ForegroundColor Yellow
            $done = $true
        }
    }
    until ($done)

}
catch 
{
    Write-Host "ERROR" $_ -ForegroundColor Red
}


}


function HexatownListRequests{
return @'
{
    "description":  "Used by the www.hexatown.com framework for requesting a batch process to run ",        
    "displayName":  "Hexatown Requests",
    "list":  {
                 "contentTypesEnabled":  false,
                 "hidden":  false,
                 "template":  "genericList"
             },
    "columns":  [
                    {
                        "columnGroup":  "Custom Columns",
                        "description":  "ID which you can use in your code to relate this request to something",
                        "displayName":  "Your Reference ID",
                        "enforceUniqueValues":  false,
                        "hidden":  false,
                        "indexed":  true,
                        "name":  "YourReferenceID",
                        "readOnly":  true,
                        "required":  false,
                        "text":  {
                                     "allowMultipleLines":  false,
                                     "appendChangesToExistingText":  false,
                                     "linesForEditing":  0,
                                     "maxLength":  255
                                 }
                    },
                    {
                        "columnGroup":  "Custom Columns",
                        "description":  "Here you put a value corresponding with your PowerBricks router logic",
                        "displayName":  "Path",
                        "enforceUniqueValues":  false,
                        "hidden":  false,
                        "indexed":  false,
                        "name":  "Path",
                        "readOnly":  false,
                        "required":  false,
                        "text":  {
                                     "allowMultipleLines":  false,
                                     "appendChangesToExistingText":  false,
                                     "linesForEditing":  0,
                                     "maxLength":  255
                                 }
                    },
                    {
                        "columnGroup":  "Custom Columns",
                        "description":  "Here you put a method, PUT, GET, PATCY, POST, DELETE corresponding to what you like your PowerBricks to do",
                        "displayName":  "Method",
                        "enforceUniqueValues":  false,
                        "hidden":  false,
                        "indexed":  false,
                        "name":  "Method",
                        "readOnly":  false,
                        "required":  false,
                        "text":  {
                                     "allowMultipleLines":  false,
                                     "appendChangesToExistingText":  false,
                                     "linesForEditing":  0,
                                     "maxLength":  255
                                 }
                    },
                    {
                        "columnGroup":  "Custom Columns",
                        "description":  "This is the 'Payload' for the request, it is the logic in the PowerBrick which dictate the format, but it is  typically in a JSON format",
                        "displayName":  "Request",
                        "enforceUniqueValues":  false,
                        "hidden":  false,
                        "indexed":  false,
                        "name":  "Request",
                        "readOnly":  false,
                        "required":  false,
                        "text":  {
                                     "allowMultipleLines":  true,
                                     "appendChangesToExistingText":  false,
                                     "textType": "plain"
                                 }
                    },
                    {
                        "columnGroup":  "Custom Columns",
                        "description":  "This is the a code indicating the process result, following internet REST API standards, so 200 is the value to look for if noting went wrong",
                        "displayName":  "Response Code",
                        "enforceUniqueValues":  false,
                        "hidden":  false,
                        "indexed":  false,
                        "name":  "ResponseCode",
                        "readOnly":  false,
                        "required":  false,
                        "number":  {
                                   "decimalPlaces": "none",
  "displayAs": "number",
  "maximum": 999,
  "minimum": 0
                                 }
                    },
                    {
                        "columnGroup":  "Custom Columns",
                        "description":  "This is the result for of the request, it is the logic in the PowerBrick which dictate the format, but it is  typically in a CSV format for easy consumption in PowerApps",
                        "displayName":  "Response",
                        "enforceUniqueValues":  false,
                        "hidden":  false,
                        "indexed":  false,
                        "name":  "Response",
                        "readOnly":  false,
                        "required":  false,
                        "text":  {
                                     "allowMultipleLines":  true,
                                     "appendChangesToExistingText":  false,
                                                                          "textType": "plain"
                                 }
                    },
                    {
                        "columnGroup":  "Custom Columns",
                        "description":  "Has this been procesed",
                        "displayName":  "Processed",
                        "enforceUniqueValues":  false,
                        "hidden":  false,
                        "indexed":  false,
                        "name":  "Processed",
                        "readOnly":  false,
                        "required":  false,
                        "boolean":  {
                                     
                                 }
                    }

                ]
}

'@
}

function HexatownListLog{
return @'
{
"description":  "Used by the www.hexatown.com framework for logging",    
    "displayName":  "Hexatown Log",
    "list":  {
                 "contentTypesEnabled":  false,
                 "hidden":  false,
                 "template":  "genericList"
             },
    "columns":  [
                    
                    {
                        "columnGroup":  "Custom Columns",
                        "description":  "",
                        "displayName":  "System",
                        "enforceUniqueValues":  false,
                        "hidden":  false,
                        "indexed":  false,
                        "name":  "System",
                        "readOnly":  false,
                        "required":  false,
                        "text":  {
                                     "allowMultipleLines":  false,
                                     "appendChangesToExistingText":  false,
                                     "linesForEditing":  0,
                                     "maxLength":  255
                                 }
                    },
                    {
                        "columnGroup":  "Custom Columns",
                        "description":  "",
                        "displayName":  "Sub System",
                        "enforceUniqueValues":  false,
                        "hidden":  false,
                        "indexed":  false,
                        "name":  "SubSystem",
                        "readOnly":  false,
                        "required":  false,
                        "text":  {
                                     "allowMultipleLines":  false,
                                     "appendChangesToExistingText":  false,
                                     "linesForEditing":  0,
                                     "maxLength":  255
                                 }
                    },
                    {
                        "columnGroup":  "Custom Columns",
                        "description":  "",
                        "displayName":  "Status",
                        "enforceUniqueValues":  false,
                        "hidden":  false,
                        "indexed":  false,
                        "name":  "Status",
                        "readOnly":  false,
                        "required":  false,
                        "text":  {
                                     "allowMultipleLines":  false,
                                     "appendChangesToExistingText":  false,
                                     "linesForEditing":  0,
                                     "maxLength":  255
                                 }
                    },
                    {
                        "columnGroup":  "Custom Columns",
                        "description":  "",
                        "displayName":  "Quantity",
                        "enforceUniqueValues":  false,
                        "hidden":  false,
                        "indexed":  false,
                        "name":  "Quantity",
                        "readOnly":  false,
                        "required":  false,
                        "number":  {
                                       "decimalPlaces":  "none",
                                       "displayAs":  "number",
                                       "maximum":  1.7976931348623157E+308,
                                       "minimum":  -1.7976931348623157E+308
                                   }
                    },
                    {
                        "columnGroup":  "Custom Columns",
                        "description":  "",
                        "displayName":  "System Reference",
                        "enforceUniqueValues":  false,
                        "hidden":  false,
                        "indexed":  false,
                        "name":  "SystemReference",
                        "readOnly":  false,
                        "required":  false,
                        "text":  {
                                     "allowMultipleLines":  false,
                                     "appendChangesToExistingText":  false,
                                     "linesForEditing":  0,
                                     "maxLength":  255
                                 }
                    },
                    {
                        "columnGroup":  "Custom Columns",
                        "description":  "",
                        "displayName":  "Details",
                        "enforceUniqueValues":  false,
                        "hidden":  false,
                        "indexed":  false,
                        "name":  "Details",
                        "readOnly":  false,
                        "required":  false,
                        "text":  {
                                     "allowMultipleLines":  true,
                                     "appendChangesToExistingText":  false,
                                     "linesForEditing":  6,
                                     "textType":  "plain"
                                 }
                    },
                    {
                        "columnGroup":  "Custom Columns",
                        "description":  "",
                        "displayName":  "Host",
                        "enforceUniqueValues":  false,
                        "hidden":  false,
                        "indexed":  false,
                        "name":  "Host",
                        "readOnly":  false,
                        "required":  false,
                        "text":  {
                                     "allowMultipleLines":  false,
                                     "appendChangesToExistingText":  false,
                                     "linesForEditing":  0,
                                     "maxLength":  255
                                 }
                    },
                    {
                        "columnGroup":  "Custom Columns",
                        "description":  "",
                        "displayName":  "Identifier",
                        "enforceUniqueValues":  false,
                        "hidden":  false,
                        "indexed":  false,
                        "name":  "Identifier",
                        "readOnly":  false,
                        "required":  false,
                        "text":  {
                                     "allowMultipleLines":  false,
                                     "appendChangesToExistingText":  false,
                                     "linesForEditing":  0,
                                     "maxLength":  255
                                 }
                    },
                    {
                        "columnGroup":  "Custom Columns",
                        "description":  "",
                        "displayName":  "Workflow",
                        "enforceUniqueValues":  false,
                        "hidden":  false,
                        "indexed":  false,
                        "name":  "Workflow",
                        "readOnly":  false,
                        "required":  false,
                        "text":  {
                                     "allowMultipleLines":  false,
                                     "appendChangesToExistingText":  false,
                                     "linesForEditing":  0,
                                     "maxLength":  255
                                 }
                    },
                    {
                        "columnGroup":  "Custom Columns",
                        "description":  "",
                        "displayName":  "Quantifier",
                        "enforceUniqueValues":  false,
                        "hidden":  false,
                        "indexed":  false,
                        "name":  "Quantifier",
                        "readOnly":  false,
                        "required":  false,
                        "text":  {
                                     "allowMultipleLines":  false,
                                     "appendChangesToExistingText":  false,
                                     "linesForEditing":  0,
                                     "maxLength":  255
                                 }
                    }
                ]
}

'@
}

function HexatownListProperties{
return @'
{
    "description":  "Used by the www.hexatown.com framework for storing key/values",
    "displayName":  "Hexatown Properties",
    "list":  {
                 "contentTypesEnabled":  false,
                 "hidden":  false,
                 "template":  "genericList"
             },
    "columns":  [
                    {
                        "columnGroup":  "Custom Columns",
                        "description":  "",
                        "displayName":  "Value",
                        "enforceUniqueValues":  false,
                        "hidden":  false,
                        "id":  "2f3ccd45-6989-416e-bf9f-2302bcccf089",
                        "indexed":  false,
                        "name":  "Value",
                        "readOnly":  false,
                        "required":  false,
                        "text":  {
                                     "allowMultipleLines":  true,
                                     "appendChangesToExistingText":  false,
                                     "linesForEditing":  6,
                                     "textType":  "plain"
                                 }
                    }
                ]
}


'@
}

function CreateCoreList($hexatown, $siteUrl,$definition) {

    GraphAPI $hexatown POST "$siteUrl/lists" $definition
    

}







