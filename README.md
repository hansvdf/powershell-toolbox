# Powershell Toolbox

A collection of small, standalone PowerShell scripts.

## Getting started

Clone the repository and add its script folders to `PATH`, so you can run the scripts by name from any folder:

```powershell
git clone https://github.com/hansvdf/powershell-toolbox.git
cd powershell-toolbox
.\setup\Add-ScriptFoldersToPath.ps1 -StorePermanently
```

The scripts are then available in this and every new PowerShell session, e.g. `Compare-Folders.ps1 -FolderA .\old -FolderB .\new`.

Leave out `-StorePermanently` to try the scripts in the current PowerShell session only.

**On macOS**, install PowerShell first (`brew install powershell`), start it with `pwsh` and run the same command with forward slashes: `./setup/Add-ScriptFoldersToPath.ps1 -StorePermanently`. The scripts then work by name inside PowerShell, not in zsh. See [PATH setup on macOS](docs/path-setup-macos.md) for how this works and how to run the scripts from zsh as well.

If PowerShell refuses to run scripts, allow local scripts for your user first:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

## Scripts

Every script has built-in help with more details and examples:

```powershell
Get-Help .\files\Compare-Folders.ps1 -Full
```

### files

| Script | Description |
| --- | --- |
| [`Compare-Folders.ps1`](files/Compare-Folders.ps1) | Compares the file names in two folders and shows a table with, for each file, whether it exists in Folder A and in Folder B. Use `-Recurse` to include subfolders and `-DifferencesOnly` to hide files that exist in both. Compares names only, not file contents. |
| [`Copy-SubfolderFiles.ps1`](files/Copy-SubfolderFiles.ps1) | Copies the files from all subfolders, at any depth, into one folder. Use `-FolderName` to only take files from folders with a given name (e.g. every `ARCHIVE` folder) and `-Destination` to copy somewhere other than the folder itself. Files with the same name are skipped with a warning instead of overwritten, unless you add `-Overwrite` for files already in the destination. Supports `-WhatIf`. |
| [`Merge-CsvFiles.ps1`](files/Merge-CsvFiles.ps1) | Merges all CSV files in a folder into one `merged.csv`, with the source file name as an extra first column on every row. Uses `;` as the delimiter by default; use `-Delimiter ','` for comma-separated files and `-HasHeader` when the files start with a header row. Reads UTF-8, UTF-16 and ANSI files and writes UTF-8 that Excel opens correctly. |

### network

| Script | Description |
| --- | --- |
| [`Get-WifiSsid.ps1`](network/Get-WifiSsid.ps1) | Shows the name (SSID) of the Wi-Fi network you are connected to. Shows a warning when no Wi-Fi network is connected. Windows only. |

### power-bi

| Script | Description |
| --- | --- |
| [`Scan-PBIXReports.ps1`](power-bi/Scan-PBIXReports.ps1) | Shows, for each PBIX file in a folder, which published Power BI workspace, report and semantic model it belongs to, looked up by ID through the Power BI REST API. Use `-Recurse` to include subfolders, `-CsvPath` to export the results and `-PassThru` to output objects instead of a table. Use `-Offline` to only show the IDs from the PBIX files, without signing in. |

Requires the [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), unless you use `-Offline`. Sign in once before running the script:

```powershell
az login --allow-no-subscriptions
Scan-PBIXReports.ps1 -FolderPath C:\Reports -Recurse
Scan-PBIXReports.ps1 -FolderPath C:\Reports -PassThru | Where-Object Status -ne 'OK'   # only files with problems
```

The Status column shows `OK` or what went wrong, for example a file that was never published or a report you don't have access to.

### setup

| Script | Description |
| --- | --- |
| [`Add-ScriptFoldersToPath.ps1`](setup/Add-ScriptFoldersToPath.ps1) | Adds a folder and all its subfolders to `PATH`. Defaults to this repository; use `-Path` for another folder. |
| [`Remove-ScriptFoldersFromPath.ps1`](setup/Remove-ScriptFoldersFromPath.ps1) | Removes a folder and all its subfolders from `PATH` again. Same parameters as the add script. |
| [`Get-ToolboxScripts.ps1`](setup/Get-ToolboxScripts.ps1) | Lists all scripts in the toolbox with a one-line description, taken from each script's built-in help. |

Both setup scripts only change `PATH` for the current PowerShell session, unless you add `-StorePermanently`. That saves the change for new sessions too: in your user `PATH` on Windows, and in your PowerShell profile on macOS (see [PATH setup on macOS](docs/path-setup-macos.md)). Dot-folders such as `.git` are never added, and neither is `docs`; use `-Exclude` to skip other folders too.

```powershell
.\setup\Add-ScriptFoldersToPath.ps1                          # this repository, current session only
.\setup\Add-ScriptFoldersToPath.ps1 -Path 'C:\Scripts'       # another folder
.\setup\Add-ScriptFoldersToPath.ps1 -StorePermanently        # also save for new sessions
.\setup\Remove-ScriptFoldersFromPath.ps1 -StorePermanently   # undo
```

The add script collects subfolders when it runs, so run it again after adding a new folder to the repository.

## License

Powershell Toolbox is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
