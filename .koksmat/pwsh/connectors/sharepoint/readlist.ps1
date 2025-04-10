function SharePointReadList {
  param (
    [string]$siteUrl,
    [string]$listName,        
    [ScriptBlock]$mapItem
  ) 
  $result = "$env:WORKDIR/$listName.json"
  write-host "$listName "  -NoNewline
  Connect-PnPOnline -Url $siteUrl  -ClientId $PNPAPPID -Tenant $PNPTENANTID -CertificatePath "$PNPCERTIFICATEPATH"

  $listItems = Get-PnpListItem -List $listName   

  write-host " $($listItems.Count) items"   -NoNewline
  $items = @()
  foreach ($item in $listItems) {
    $mappeditem = & $mapItem $item        
    $items += $mappeditem
  }

  $items | ConvertTo-Json -Depth 10 | Out-File -FilePath $result -Encoding utf8NoBOM
  write-host " written to $result"
}