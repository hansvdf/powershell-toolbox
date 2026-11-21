# powershell-toolbox

A collection of small, standalone PowerShell scripts.

## Getting started

Clone the repository and add its script folders to `PATH`, so you can run the scripts by name from any folder:

```powershell
git clone https://github.com/hansvdf/powershell-toolbox.git
cd powershell-toolbox
.\setup\Add-ScriptFoldersToPath.ps1 -StorePermanently
```

The scripts are then available in this and every new terminal, e.g. `Compare-Folders.ps1 -FolderA .\old -FolderB .\new`.

Leave out `-StorePermanently` to try the scripts in the current PowerShell session only.

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
| [`Compare-Folders.ps1`](files/Compare-Folders.ps1) | Compares the file names in two folders and lists the names found only in Folder A, only in Folder B, or in both. Use `-Recurse` to include subfolders. Compares names only, not file contents. |

### setup

| Script | Description |
| --- | --- |
| [`Add-ScriptFoldersToPath.ps1`](setup/Add-ScriptFoldersToPath.ps1) | Adds a folder and all its subfolders to `PATH`. Defaults to this repository; use `-Path` for another folder. |
| [`Remove-ScriptFoldersFromPath.ps1`](setup/Remove-ScriptFoldersFromPath.ps1) | Removes a folder and all its subfolders from `PATH` again. Same parameters as the add script. |

Both setup scripts only change `PATH` for the current PowerShell session, unless you add `-StorePermanently` to also update your user `PATH`. Dot-folders such as `.git` are never added.

```powershell
.\setup\Add-ScriptFoldersToPath.ps1                          # this repository, current session only
.\setup\Add-ScriptFoldersToPath.ps1 -Path 'C:\Scripts'       # another folder
.\setup\Add-ScriptFoldersToPath.ps1 -StorePermanently        # also save to the user PATH
.\setup\Remove-ScriptFoldersFromPath.ps1 -StorePermanently   # undo
```

The add script collects subfolders when it runs, so run it again after adding a new folder to the repository.

## License

[MIT](LICENSE)
