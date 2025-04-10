# Hexatown PowerShell Framework (v2.0.8)

**Author:** Niels Gregers Johansen  
**License:** MIT (See full license text below)  
**Version:** 2.0.8

This PowerShell framework provides a comprehensive set of functions and utilities for automating tasks involving Microsoft Graph, SharePoint Online, and Exchange Online. Its primary purpose is to serve as a backend "engine" that orchestrates reading and writing to SharePoint lists, handling requests/responses via Graph API, integrating with Exchange Online, and providing logging and utility methods to streamline complex automation workflows.

## Key Features

- **Authentication & Token Management:**

  - Acquire and manage OAuth tokens for the Microsoft Graph.
  - Support for both client credentials and delegated (device code) flows.
  - Refresh token handling for long-running or recurring operations.

- **Microsoft Graph Integration:**

  - Functions like `GraphAPI` and `GraphAPIAll` for making REST calls to the Microsoft Graph API.
  - Pagination handling with `@odata.nextLink` for iterating through large result sets.
  - Utility functions to find SharePoint site IDs by URL and to interact with SharePoint Lists.

- **SharePoint Operations:**

  - Reading SharePoint Lists (including handling pagination and non-indexed queries).
  - Creating, updating, and deleting list items.
  - Logging events and errors to a designated "Log" SharePoint list.
  - Utility functions for working with SharePoint items, removing standard properties, and building dictionaries for comparison or synchronization.

- **Exchange Online Connectivity:**

  - Certificate-based authentication to Exchange Online via `ConnectExchange2` (app-only) or credential-based (`ConnectExchange` with username and password).
  - Ability to integrate Exchange data into workflows (e.g., reading mailboxes, sending emails).

- **Error Handling & Logging:**
  - Capturing errors and writing them to a "Log" SharePoint list for auditing.
  - Graceful degradation with functions like `ReportErrors` and `Done` to ensure cleanup and reporting on exit.
- **Data Synchronization & Delta Building:**

  - Functions to compare "master" and "slave" datasets, identify changes, and generate a "delta" for synchronization.
  - Capabilities to sync SharePoint list data with external sources by building these deltas and applying updates accordingly.

- **Request Handling (Hexatown Requests):**
  - A mechanism (`Serve` function) to continuously poll a SharePoint "Requests" list for pending requests, process them, and post responses back.
  - Automatically provisions a structure and patterns for building APIs and integrating with the PowerBricks ecosystem.

## Version History

**2.0.8**

- Bug fix related to execution and assuming fields in a SharePoint list.

**2.0.7**

- Fixed error in selecting SharePoint sites based on `$top` filter.

**2.0.6**

- Added defaults for initialization functions (`Init` with `$otherOptions`).

**2.0.5**

- Changes to Exchange authentication and improved error handling.
- Various bug fixes.

**2.0.4**

- Removed malicious fields.

**2.0.3**

- Added missing trailing space in output.

**2.0.2**

- Bug fix.

**2.0.1**

- Introduced `APICAPTURE` env variable for creating files and directories if not present.

**2.0.0**

- Breaking change to Exchange authentication logic.
- Introduced a `connectToExchangeUserNamePassword=$true` option for username/password-based Exchange auth.

**1.1.13 and earlier**

- Updates to `Send-Hexatown-Mail` for parameter `ContentType`.
- Inclusion of SharePoint list definitions and a `Serve` function.
- Support for SharePoint delegate mode.
- Enhancements to module installation checks, logging, and environment configuration.

## Setup & Prerequisites

1. **PowerShell:**  
   Ensure you have at least PowerShell 5.1 (Windows) or [PowerShell 7+](https://github.com/PowerShell/PowerShell) installed.

2. **Azure AD App Registration:**  
   You need an Azure AD application with appropriate Microsoft Graph permissions.  
   Environment Variables (required):

   - `APPCLIENT_ID`: Your application (client) ID.
   - `APPCLIENT_SECRET`: Client secret of the registered app.
   - `APPCLIENT_DOMAIN`: Your Azure AD tenant’s domain (e.g., `contoso.onmicrosoft.com`).
   - `SITEURL`: The SharePoint site URL from which you read/write lists.

   Optional environment variables:

   - `HEXATOWNURL`: Another SharePoint site URL if you wish to log events to a "Hexatown Log" list located there.
   - `ENV:APICAPTURE`: If set, creates directories and files for API captures.

3. **Exchange Online:**

   - For certificate-based app-only auth:
     - `EXCHAPPID`
     - `EXCHORGANIZATION`
     - `EXCHCERTIFICATE` (Base64 encoded `.pfx`)
     - `EXCHCERTIFICATEPASSWORD`
   - Or, for username/password-based auth:
     - `AADUSER`
     - `AADPASSWORD`

4. **Module Dependencies:**

   - `ExchangeOnlineManagement` (required for Exchange connectivity, must be placed in `modules` directory or be installed system-wide).

5. **.env Configuration:**
   The script attempts to load environment variables from a `.env` file. Use `DotEnvConfigure` for environment variable handling.

## Usage Examples

- **Initialize Hexatown Environment:**

  ```powershell
  $hexatown = Start-HexatownApp $MyInvocation @{
    connectToSharePoint = $true
    SkipTranscript = $false
  }
  ```

- **Fetch All Items from a SharePoint List:**

  ```powershell
  $items = SharePointRead $hexatown "/Lists/YourListName/items?$expand=fields"
  $items.Count # Number of items retrieved
  ```

- **Log an Event:**

  ```powershell
  Write-Hexatown-Log $hexatown "MyEvent" "OK" "SystemName" "SubsystemName" "Ref123" 10 "Operation completed successfully."
  ```

- **Process Requests Continuously (Serve Loop):**

  ```powershell
  Serve -hexatown $hexatown -minutes 30
  ```

- **Stop and Cleanup:**
  ```powershell
  Stop-Hexatown $hexatown
  ```

## Troubleshooting

- **Authentication Errors:**  
  Check your environment variables, ensure app permissions are correctly granted in Azure AD, and verify that your tenant domain is correct.

- **SharePoint Connectivity Issues:**  
  Confirm `SITEURL` is set and accessible. Ensure proper SharePoint permissions for the registered application.

- **Exchange Connectivity Problems:**  
  Check that your certificate is valid, the password is correct, and the ExchangeOnlineManagement module is installed. Ensure that the Azure AD app has the required roles for Exchange Online.

- **APICAPTURE Not Creating Files:**  
  Ensure `ENV:APICAPTURE` is set to a non-empty value and the script can write to the specified directories.
