# Initial Setup for `magic-mix`

This script ensures that the working directory is properly set and prepares the `magic-mix` tool for use. It will:

1. Set a working directory (`WORKDIR`) if not already defined.
2. Clone the `magic-mix` repository from GitHub into the working directory.
3. Navigate into the cloned `magic-mix` project.
4. Install necessary tooling using `go install`.
5. Test connectivity to your SQL database with a sample query (`SELECT 1`).

## How It Works

- **Set and Validate `WORKDIR`:**  
  If the `$env:WORKDIR` environment variable is not defined, it defaults to `../.koksmat/workdir` relative to the current script directory.  
  If the directory does not exist, it is created.

- **Clone `magic-mix` Repository:**  
  The script uses `git clone --depth=1` to fetch the `magic-mix` repository quickly with minimal history.  
  This repository is placed inside the `$WORKDIR`.

- **Install Dependencies with Go:**  
  After cloning, it changes location to the `app` folder where `go install` is executed.  
  This step ensures that any necessary Go binaries are built and installed locally.

- **Verify SQL Connectivity:**  
  A test SQL query (`SELECT 1`) is run via `magic-mix sql query mix` to confirm that `magic-mix` and the database are configured correctly.

## Prerequisites

- **Git:**  
  The script uses `git` to clone the repository, so ensure `git` is installed and available in your `PATH`.

- **Go (Golang):**  
  You must have Go installed and configured in your environment for `go install` to work.

- **Database Connectivity:**  
  Ensure that `magic-mix` is properly configured to connect to your SQL database. Any required environment variables or configuration files should be set up beforehand.

## Error Handling

- If the repository cannot be cloned or a step fails, the script will write an error message and continue.
- Check the console output if something goes wrong.

## Example

```powershell
# Set environment variables (if not already set)
$env:WORKDIR = "C:\Path\To\WorkDir"


# Run the script
.\connect.ps1
```
