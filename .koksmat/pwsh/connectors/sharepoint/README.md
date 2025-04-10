# PnP PowerShell Connection Scripts

This repository contains two PowerShell scripts designed to streamline the installation and connection process for the [PnP.PowerShell](https://pnp.github.io/powershell/) module, which is essential for managing SharePoint Online and other Microsoft 365 services.

- **`install.ps1`**: Automates the installation of the PnP.PowerShell module.
- **`connect.ps1`**: Establishes a secure connection to a specified SharePoint Online site using certificate-based authentication.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Environment Variables](#environment-variables)
- [Troubleshooting](#troubleshooting)
- [License](#license)
- [Additional Resources](#additional-resources)

## Prerequisites

Before using these scripts, ensure that you have the following prerequisites in place:

1. **PowerShell 7+**: The scripts are optimized for PowerShell version 7 and above. You can download the latest version from the [official PowerShell GitHub repository](https://github.com/PowerShell/PowerShell).

2. **Azure AD Application Registration**:

   - **Client ID (`PNPAPPID`)**: The Application (client) ID from your Azure AD app registration.
   - **Tenant ID (`PNPTENANTID`)**: Your Azure AD tenant ID.
   - **Certificate**: A valid `.pfx` certificate file for certificate-based authentication.

3. **PnP.PowerShell Module**: The `install.ps1` script will handle the installation, but ensure you have the necessary permissions to install modules for the current user.

4. **SharePoint Online Site**: The URL of the SharePoint site you intend to connect to.

## Installation

To set up the environment, follow these steps:

1. **Clone the Repository**:

   ```bash
   git clone https://github.com/yourusername/your-repo.git
   cd your-repo
   ```

2. **Run the Installation Script**:
   Execute the `install.ps1` script to install the PnP.PowerShell module.

   ```powershell
   ./install.ps1
   ```

   **What It Does**:

   - Installs the `PnP.PowerShell` module from the PowerShell Gallery.
   - Forces installation to ensure the latest version is acquired.
   - Allows prerelease versions if available.
   - Installs the module for the current user to avoid requiring administrative privileges.

## Configuration

Before running the connection script, you need to configure the necessary environment variables. These variables store sensitive information required for authentication and connection.

### Setting Environment Variables

You can set the environment variables in your PowerShell session or add them to your profile for persistence.

```powershell
# Replace the placeholder values with your actual configuration
$env:PNPAPPID = "your-azure-ad-app-id"
$env:PNPTENANTID = "your-azure-ad-tenant-id"
$env:PNPCERTIFICATE = "base64-encoded-pfx-certificate-string"
$env:PNPSITE = "https://yourtenant.sharepoint.com/sites/yoursite"
```

**Notes**:

- **`PNPCERTIFICATE`**: This should be a Base64-encoded string of your `.pfx` certificate file. You can encode your certificate using the following command:

  ```powershell
  [Convert]::ToBase64String((Get-Content -Path "path\to\your\certificate.pfx" -Encoding Byte))
  ```

  Replace `"path\to\your\certificate.pfx"` with the actual path to your certificate file.

- Ensure that the certificate has the necessary permissions and is correctly associated with your Azure AD application for authentication.

## Usage

### Connecting to SharePoint Online

After setting up the environment variables and installing the necessary module, use the `connect.ps1` script to establish a connection to your SharePoint Online site.

```powershell
./connect.ps1
```

**What It Does**:

1. **Reads Environment Variables**:

   - `PNPAPPID`: Your Azure AD application's Client ID.
   - `PNPTENANTID`: Your Azure AD Tenant ID.
   - `PNPCERTIFICATE`: Base64-encoded `.pfx` certificate.
   - `PNPSITE`: URL of the SharePoint Online site.

2. **Decodes and Writes Certificate**:

   - Decodes the Base64-encoded certificate and saves it to the specified path (`pnp.pfx`) within the script's directory.

3. **Establishes Connection**:
   - Uses the `Connect-PnPOnline` cmdlet with the provided credentials and certificate to authenticate and connect to the SharePoint site.

**Example Output**:

```plaintext
Connecting to https://yourtenant.sharepoint.com/sites/yoursite
Connected to https://yourtenant.sharepoint.com/sites/yoursite
```

## Environment Variables

| Variable         | Description                                           | Required | Example                                            |
| ---------------- | ----------------------------------------------------- | -------- | -------------------------------------------------- |
| `PNPAPPID`       | Azure AD Application (Client) ID                      | Yes      | `c5e8d82e-2715-4a89-9eaa-ff8d8ed4b36f`             |
| `PNPTENANTID`    | Azure AD Tenant ID                                    | Yes      | `your-tenant-id-guid`                              |
| `PNPCERTIFICATE` | Base64-encoded `.pfx` certificate string              | Yes      | `MIIC...base64encodedstring...=`                   |
| `PNPSITE`        | SharePoint Online Site URL                            | Yes      | `https://yourtenant.sharepoint.com/sites/yoursite` |
| `HEXATOWNHOME`   | (Optional) Home directory for Hexatown configurations | No       | `C:\Hexatown`                                      |
| `DEBUG`          | (Optional) Enable debug mode                          | No       | `true`                                             |
| `VERBOSE`        | (Optional) Enable verbose output                      | No       | `true`                                             |
| `APICAPTURE`     | (Optional) Enable API capture functionality           | No       | `true`                                             |

## Troubleshooting

### Common Issues

1. **Module Installation Failures**:

   - **Error**: `Install-Module` fails due to lack of permissions.
   - **Solution**: Ensure you're running PowerShell with sufficient privileges or use the `-Scope CurrentUser` parameter as in the `install.ps1` script.

2. **Authentication Errors**:

   - **Error**: Unable to connect to SharePoint Online.
   - **Solution**:
     - Verify that all environment variables are correctly set.
     - Ensure the Azure AD application has the necessary permissions for SharePoint Online.
     - Check that the certificate is valid and correctly encoded.

3. **Certificate Issues**:

   - **Error**: Invalid certificate path or decoding issues.
   - **Solution**:
     - Ensure the `PNPCERTIFICATE` environment variable contains a valid Base64-encoded `.pfx` certificate.
     - Verify that the certificate matches the one registered in Azure AD.

4. **Connection Timeout**:
   - **Error**: The connection to SharePoint Online times out.
   - **Solution**:
     - Check your network connectivity.
     - Ensure that the SharePoint site URL (`PNPSITE`) is correct and accessible.
     - Verify that there are no firewall rules blocking the connection.

### Enabling Verbose Logging

For more detailed logs during script execution, set the `VERBOSE` environment variable to `true`:

```powershell
$env:VERBOSE = "true"
```

## Additional Resources

- [PnP.PowerShell Documentation](https://pnp.github.io/powershell/)
- [Azure AD App Registrations](https://docs.microsoft.com/azure/active-directory/develop/quickstart-register-app)
- [Certificate-Based Authentication for SharePoint Online](https://docs.microsoft.com/sharepoint/dev/solution-guidance/security-apponly-azureacs)
- [PowerShell Invoke-RestMethod](https://docs.microsoft.com/powershell/module/microsoft.powershell.utility/invoke-restmethod)
- [PowerShell Environment Variables](https://docs.microsoft.com/powershell/module/microsoft.powershell.core/about/about_environment_variables)

---

**Note**: Always ensure that sensitive information such as client secrets and certificates are securely managed and not exposed in source control or logs.
