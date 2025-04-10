# Demo script

This is an example of how to work with a script that depends on an environment variable, and fail if it is not defined and also an example on how you can run it locally as well as having it support execution in GitHub by being called from a GitHub action.

## Debug locally

To debug `run.ps1` file you open and run the `debug.ps1` file. 

The `debug.ps1` file basically set the current working directory to the current folder, then generates and execute a `temp.ps1` and finally calls the `run.ps1`.

When running PowerShell is Visual Studio Code a process is started and reused, so you only need to run the `debug.ps1` command once.


```powershell
Push-Location
try {
  Set-Location $PSScriptRoot
  
  . "$PSScriptRoot/../.koksmat/pwsh/build-env.ps1"
  . "$PSScriptRoot/temp.ps1"
  . "$PSScriptRoot/run.ps1"
}
catch {
  write-host "Error: $_" -ForegroundColor:Red
  <#Do this if a terminating exception happens#>
}
finally {
  Pop-Location
}

```



## Running in a GitHub action

So please check the `.github/workflows/demo.yaml` file - For your convenience the content of the file is here - the relation between the action definition and the script in this folder is found in the line `run: pwsh ./_demo/run.ps1`.




```yaml
name: Demo
on:

  workflow_dispatch: 
    inputs:
      hello:
        description: "Hello"
        required: true
        default: "world"

jobs:
  run-scripts:
    runs-on: ubuntu-latest
    env:
      WORKDIR: ${{ github.workspace }}
      HELLO: ${{ github.event.inputs.hello }}

    steps:
      - name: Check out repository
        uses: actions/checkout@v3

      - name: Run Demo Script
        run: pwsh ./_demo/run.ps1
        shell: pwsh


```
