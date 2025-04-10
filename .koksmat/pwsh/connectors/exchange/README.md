# Exchange Online Connection Scripts

This directory contains two scripts that help manage and automate the connection to Exchange Online via PowerShell:

- **`install.ps1`**: Installs the required `ExchangeOnlineManagement` PowerShell module.
- **`connect.ps1`**: Connects to an Exchange Online organization using provided environment variables and a certificate.

## Prerequisites

- **PowerShell 5.1 or later** (on Windows) or [PowerShell 7+](https://github.com/PowerShell/PowerShell) on other platforms.
- An Exchange Online tenant with API access configured.
- A valid client certificate and application registration for Exchange Online.
- The following environment variables must be set:
  - `EXCHAPPID`: The Application (Client) ID of the Azure AD app used to connect.
  - `EXCHORGANIZATION`: The tenant's organization domain for Exchange Online.
  - `EXCHCERTIFICATE`: A Base64-encoded string representing the client certificate `.pfx` file.
  - `EXCHCERTIFICATEPASSWORD` (optional): The password for the certificate, if one is required.

## Scripts Overview

### `install.ps1`

**Purpose:**  
Installs the `ExchangeOnlineManagement` module, which provides the `Connect-ExchangeOnline` cmdlet and other functions for managing Exchange Online environments.

**What It Does:**

- Executes `Install-Module -Name ExchangeOnlineManagement -Force`.
- Ensures you have the latest version of the module.

**How to Run:**

```powershell
.\install.ps1
```

### `connect.ps1`

**Purpose:**  
Authenticates and connects to an Exchange Online environment using a certificate-based authentication flow.

**What It Does:**

1. Reads environment variables for configuration:
   - `EXCHAPPID`
   - `EXCHORGANIZATION`
   - `EXCHCERTIFICATE`
   - `EXCHCERTIFICATEPASSWORD` (if provided)
2. Creates a `.pfx` file from the `EXCHCERTIFICATE` environment variable.
3. Uses `Connect-ExchangeOnline` with the provided app ID, certificate, and organization.
4. If a certificate password is provided, it’s converted to a secure string and passed to the connection.
5. If no password is required, it will connect using just the certificate file and app ID.

**How to Run:**

```powershell
.\connect.ps1
```

If your environment variables are properly set, you should see output confirming a connection to your specified Exchange Online organization.

## Setting Environment Variables

You can set these environment variables in your PowerShell session before running the scripts:

```powershell
$env:EXCHAPPID = "your-azure-ad-app-id"
$env:EXCHORGANIZATION = "yourdomain.onmicrosoft.com"
$env:EXCHCERTIFICATE = "<Base64-encoded-certificate-string>"
$env:EXCHCERTIFICATEPASSWORD = "your-certificate-password"
```

_Note:_ If the certificate does not have a password, `EXCHCERTIFICATEPASSWORD` can be omitted.

## Troubleshooting

- **Module Not Found:**  
  If `Connect-ExchangeOnline` is not recognized, ensure you’ve run `.\install.ps1` or have `ExchangeOnlineManagement` installed.

- **Authentication Failures:**  
  Verify your `EXCHAPPID`, `EXCHORGANIZATION`, and certificate details. Ensure your Azure AD application is properly configured for app-only authentication to Exchange Online, and that the certificate is valid and not expired.

- **Certificate Issues:**
  Confirm that the Base64-encoded string is a valid `.pfx` certificate and that `EXCHCERTIFICATEPASSWORD` (if provided) matches the certificate’s password.

## Additional Resources

- [Exchange Online PowerShell](https://learn.microsoft.com/powershell/exchange/exchange-online-powershell?view=exchange-ps)
- [Certificate-Based Authentication in Azure AD](https://learn.microsoft.com/azure/active-directory/develop/authentication-scenarios-for-azure-ad)
- [Connect-ExchangeOnline cmdlet Documentation](https://learn.microsoft.com/powershell/module/exchangeonlinemanagement/connect-exchangeonline)
