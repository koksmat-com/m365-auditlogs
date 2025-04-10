# Microsoft Graph Utilities

This PowerShell script provides a set of utility functions and logic to interact with the Microsoft Graph API, primarily for reading SharePoint site metadata and other Graph-managed entities.

## Overview

### Functions

1. **FindSiteIdByUrl($token, $siteUrl)**  
   Given a valid Graph API OAuth access token and a SharePoint site URL, this function:

   - Adjusts the URL format to match Graph's site identification endpoints.
   - Queries the Microsoft Graph API to find the corresponding `site.id`.
   - Returns the `site.id` for further operations, such as listing libraries or drive items.

2. **GraphAPI($token, $method, $url, $body)**  
   A generic wrapper around `Invoke-RestMethod` for calling Microsoft Graph endpoints. It:

   - Sends requests with the provided HTTP method (`GET`, `POST`, `PATCH`, etc.).
   - Uses the provided token for bearer authorization.
   - Accepts a request body when required.
   - Returns the response from the Graph API.

3. **GraphAPIAll($token, $method, $url)**  
   For scenarios where results are paginated by the Graph API, this function:
   - Fetches all pages of data by following `@odata.nextLink` references.
   - Aggregates all returned `value` arrays into a single data set.
   - Reports progress as it iterates through multiple pages of results.
   - Returns a combined list of all retrieved records.

### Authentication

The script also demonstrates how to acquire a token for Microsoft Graph using OAuth client credentials:

- It constructs a `POST` request with the Azure AD application credentials (`GRAPH_APPID`, `GRAPH_APPSECRET`) and requested scope (`https://graph.microsoft.com/.default`).
- Retrieves an access token from the specified tenant (`GRAPH_APPDOMAIN`).
- Stores the access token in the `GRAPH_ACCESSTOKEN` environment variable.

## Prerequisites

- **PowerShell 5.1 or later** (Windows) or [PowerShell 7+](https://github.com/PowerShell/PowerShell) on other platforms.
- A registered Azure AD application with:
  - `GRAPH_APPID`: The Application (Client) ID.
  - `GRAPH_APPSECRET`: The Client Secret.
  - `GRAPH_APPDOMAIN`: Your Azure AD tenant's domain (e.g., `contoso.onmicrosoft.com`).
- Appropriate Microsoft Graph API permissions granted (e.g., `Sites.Read.All`) for reading SharePoint site data.
- Environment variables set for `GRAPH_APPID`, `GRAPH_APPSECRET`, and `GRAPH_APPDOMAIN`.

### Example of Setting Environment Variables

```powershell
$env:GRAPH_APPID = "your-app-id"
$env:GRAPH_APPSECRET = "your-client-secret"
$env:GRAPH_APPDOMAIN = "yourtenant.onmicrosoft.com"
```

## Usage

1. **Obtain an Access Token:**
   The script automatically requests and retrieves an access token by running:

   ```powershell
   $scope = "https%3A//graph.microsoft.com/.default"
   # ... (token request logic)
   $env:GRAPH_ACCESSTOKEN = $response.access_token
   ```

2. **Find a Site ID by URL:**

   ```powershell
   $token = $env:GRAPH_ACCESSTOKEN
   $siteUrl = "https://contoso.sharepoint.com/sites/Marketing"

   $siteId = FindSiteIdByUrl -token $token -siteUrl $siteUrl
   Write-Host "The site ID is: $siteId"
   ```

3. **Make a Generic Graph Call:**

   ```powershell
   $url = "https://graph.microsoft.com/v1.0/sites/$siteId/drives"
   $drives = GraphAPI -token $token -method 'GET' -url $url -body $null
   Write-Host "Found $($drives.value.Count) drives"
   ```

4. **Retrieve All Items from a Paginated Endpoint:**
   ```powershell
   $allItemsUrl = "https://graph.microsoft.com/v1.0/sites/$siteId/lists/{listId}/items"
   $allItems = GraphAPIAll -token $token -method 'GET' -url $allItemsUrl
   Write-Host "Retrieved $($allItems.Count) items across all pages"
   ```

## Troubleshooting

- **Authentication Issues:**
  Verify your client ID, secret, and domain. Ensure the Azure AD app has the necessary API permissions granted and admin consented.

- **Permission Errors (403 Forbidden):**
  Check that the signed-in identity represented by the client credentials has the required permissions (e.g., `Sites.Read.All`).

- **Invalid Site URLs:**
  Ensure that the site URL is in the correct format and accessible. The function modifies the URL to a Graph-friendly format. If the site doesn't exist or the token lacks permission, the request may fail.

- **Paginated Results Not Returning All Data:**
  Verify that the endpoint supports pagination and that all `@odata.nextLink` pages are followed by the function.

## Additional Resources

- [Microsoft Graph Documentation](https://docs.microsoft.com/graph/)
- [Microsoft Graph PowerShell SDK](https://docs.microsoft.com/powershell/microsoftgraph/)
- [Azure AD App Registration](https://docs.microsoft.com/azure/active-directory/develop/app-registrations-and-enterprise-applications)
