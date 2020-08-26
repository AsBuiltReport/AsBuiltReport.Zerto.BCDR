<p align="center">
    <a href="https://www.asbuiltreport.com/" alt="AsBuiltReport"></a> 
            <img src='https://raw.githubusercontent.com/AsBuiltReport/AsBuiltReport/master/AsBuiltReport.png' width="8%" height="8%" /></a>
</p>
<p align="center">
    <a href="https://www.powershellgallery.com/packages/AsBuiltReport.Zerto.ZVM/" alt="PowerShell Gallery Version">
        <img src="https://img.shields.io/powershellgallery/v/AsBuiltReport.Zerto.ZVM.svg" /></a>
    <a href="https://www.powershellgallery.com/packages/AsBuiltReport.Zerto.ZVM/" alt="PS Gallery Downloads">
        <img src="https://img.shields.io/powershellgallery/dt/AsBuiltReport.Zerto.ZVM.svg" /></a>
    <a href="https://www.powershellgallery.com/packages/AsBuiltReport.Zerto.ZVM/" alt="PS Platform">
        <img src="https://img.shields.io/powershellgallery/p/AsBuiltReport.Zerto.ZVM.svg" /></a>
</p>
<p align="center">
    <a href="https://github.com/AsBuiltReport/AsBuiltReport.Zerto.ZVM/graphs/commit-activity" alt="GitHub Last Commit">
        <img src="https://img.shields.io/github/last-commit/AsBuiltReport/AsBuiltReport.Zerto.ZVM/master.svg" /></a>
    <a href="https://raw.githubusercontent.com/AsBuiltReport/AsBuiltReport.Zerto.ZVM/master/LICENSE" alt="GitHub License">
        <img src="https://img.shields.io/github/license/AsBuiltReport/AsBuiltReport.Zerto.ZVM.svg" /></a>
    <a href="https://github.com/AsBuiltReport/AsBuiltReport.Zerto.ZVM/graphs/contributors" alt="GitHub Contributors">
        <img src="https://img.shields.io/github/contributors/AsBuiltReport/AsBuiltReport.Zerto.ZVM.svg"/></a>
</p>
<p align="center">
    <a href="https://twitter.com/AsBuiltReport" alt="Twitter">
            <img src="https://img.shields.io/twitter/follow/AsBuiltReport.svg?style=social"/></a>
</p>

# Zerto ZVM As Built Report

## :books: Sample Reports

# :beginner: Getting Started
Below are the instructions on how to install, configure and generate a Zerto ZVM As Built report.

## :floppy_disk: Supported Versions
### **Zerto**
The Zerto ZVM As Built Report supports the following Zerto versions;
- TBD

### **PowerShell**
This report is compatible with the following PowerShell versions;

| Windows PowerShell 5.1 |  PowerShell Core   |    PowerShell 7    |
|:----------------------:|:------------------:|:------------------:|
|   :white_check_mark:   | :white_check_mark: | :white_check_mark: |

## :wrench: System Requirements

Each of the following modules will be automatically installed by following the [module installation](https://github.com/AsBuiltReport/AsBuiltReport.Zerto.ZVM#package-module-installation) procedure.

These modules may also be manually installed.

| Module Name        | Minimum Required Version |                              PS Gallery                               |                                   GitHub                                    |
|--------------------|:------------------------:|:---------------------------------------------------------------------:|:---------------------------------------------------------------------------:|
| PScribo            |          0.9.1           |      [Link](https://www.powershellgallery.com/packages/PScribo)       |         [Link](https://github.com/iainbrighton/PScribo/tree/master)         |
| AsBuiltReport.Core |          1.1.0           | [Link](https://www.powershellgallery.com/packages/AsBuiltReport.Core) | [Link](https://github.com/AsBuiltReport/AsBuiltReport.Core/releases/latest) |

### :closed_lock_with_key: Required Privileges


## :package: Module Installation

### **PowerShell**
Open a PowerShell terminal window and install the required modules as follows;
```powershell
install-module -Name AsBuiltReport.Zerto.ZVM
```

### **GitHub**
If you are unable to use the PowerShell Gallery, you can still install the module manually. Ensure you repeat the following steps for the [system requirements](https://github.com/AsBuiltReport/AsBuiltReport.Zerto.ZVM#wrench-system-requirements) also.

1. Download the [latest release](https://github.com/AsBuiltReport/AsBuiltReport.Zerto.ZVM/releases/latest) zip from GitHub
2. Extract the zip file
3. Copy the folder `AsBuiltReport.Zerto.ZVM` to a path that is set in `$env:PSModulePath`. By default this could be `C:\Program Files\WindowsPowerShell\Modules` or `C:\Users\<user>\Documents\WindowsPowerShell\Modules`
4. Open a PowerShell terminal window and unblock the downloaded files with 
    ```powershell
    $path = (Get-Module -Name AsBuiltReport.Zerto.ZVM -ListAvailable).ModuleBase; Unblock-File -Path $path\*.psd1; Unblock-File -Path $path\Src\Public\*.ps1; Unblock-File -Path $path\Src\Private\*.ps1
    ```
5. Close and reopen the PowerShell terminal window.

_Note: You are not limited to installing the module to those example paths, you can add a new entry to the environment variable PSModulePath if you want to use another path._

## :pencil2: Configuration
The Zerto ZVM As Built Report utilises a JSON file to allow configuration of report information, options, detail and healthchecks. 

A Zerto ZVM report configuration file can be generated by executing the following command;
```powershell
New-AsBuiltReportConfig -Report Zerto.ZVM -FolderPath <User specified folder> -Filename <Optional> 
```
