# Develop, debug and Run PowerShell

This repository is a template that you can use to developed and debug PowerShell locally and and execute globally as GitHub actions. We recommend that you run this using GitHub code spaces. 

## File and folder names

I recommend that you organise your scripts so that there for each use cases is a folder with a relevant name, prefix folder names with numbers to control the order.

## Configuration Management

Environment variables are used as the single source for all types of configurations, the variable can contain confidential information.

When developing and debugging, you store environment variables in a local file called `.env`- We have made a helper function which can read the .env file from the current folder and up trough the file system, so that you can have multiple `.env

## Documentation

All folders shall have a `README.md` file describing the content of the folder, so feel free and navigate through the different folder. Suggest you do this directly in GitHub as that will make GitHub render the README.md file.

## Content of template
The template initial had this content
```
tree -ad
.
├── .devcontainer
├── .github
│   └── workflows
├── .koksmat
│   ├── pwsh
│   │   └── connectors
│   │       ├── application
│   │       ├── azure-storage
│   │       ├── exchange
│   │       ├── github
│   │       ├── graph
│   │       ├── hexatown
│   │       ├── magic-mix
│   │       └── sharepoint
│   └── workdir
├── .oldscripts
├── .vscode
└── demo

```

Let me explain:

## Folder structure

### .devcontainer
Stores information related to the configuration of at Code Space

### .github
Stores information related to the configuration of GitHub features, here we use `workflows`

### .koksmat
Contains stuff provided by `koksmat`

There is 2 subfolders in play - `.koksmat/connectors` containing a folder for each type of connector and `.koksmat/workdir` which is use a a well known directory for temporary file storage. This folder is excluded from being stored in git by being defined in a `.gitgnore`.

### .oldscripts
A folder where you should place your legacy scripts. The reason for prefixing the folder name with a `.` is that this on none Windows environments is the way to make a file hidden. This for prepare to extracting scripts to a documentation tool excluding old scripts.

### .vscode
Use for configuring features in Visual Studio Code

