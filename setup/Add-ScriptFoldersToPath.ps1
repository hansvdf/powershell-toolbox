<#
.SYNOPSIS
Adds a folder and all its subfolders to PATH.

.DESCRIPTION
Adds the folder and every subfolder below it to PATH, so scripts in them
can be run by name from anywhere. Dot-folders (.git, .vscode, ...) and
everything inside them are skipped.

By default, PATH is only updated for the current PowerShell session. Use
-StorePermanently to also save it to the user PATH, so new terminals pick
it up too. Existing entries keep their order; duplicates
(case-insensitive) and empty entries are removed.

Subfolders are collected when the script runs. Run it again after adding
new subfolders.

.PARAMETER Path
The folder to add. Defaults to the powershell-toolbox folder (the parent
of the folder this script is in).

.PARAMETER StorePermanently
Also saves the folders to the user PATH, so they stay on PATH in new
terminals. Without it, the folders are gone once this PowerShell window
is closed.

.EXAMPLE
PS> .\setup\Add-ScriptFoldersToPath.ps1

Adds the powershell-toolbox folder and its subfolders to PATH for this
PowerShell session.

.EXAMPLE
PS> .\setup\Add-ScriptFoldersToPath.ps1 -Path 'C:\Scripts'

Adds C:\Scripts and its subfolders to PATH for this PowerShell session.

.EXAMPLE
PS> .\setup\Add-ScriptFoldersToPath.ps1 -StorePermanently

Adds the powershell-toolbox folder and its subfolders to PATH for this
session and saves them to the user PATH.
#>

param(
    [ValidateScript({
        if (Test-Path -LiteralPath $_ -PathType Container) { return $true }
        throw "Folder '$_' does not exist."
    })]
    [string]$Path = (Split-Path -Parent $PSScriptRoot),

    [switch]$StorePermanently
)

$scriptRoot = (Resolve-Path -LiteralPath $Path).ProviderPath.TrimEnd('\', '/')

# All subfolders, except dot-folders (.git, .vscode, ...) and anything inside them.
$folders = @($scriptRoot) + @(
    Get-ChildItem -LiteralPath $scriptRoot -Directory -Recurse |
        Where-Object {
            $relative = $_.FullName.Substring($scriptRoot.Length).TrimStart('\', '/')
            -not ($relative -split '[\\/]' | Where-Object { $_ -like '.*' })
        } |
        Select-Object -ExpandProperty FullName
)

# Appends folders to a ';'-separated path list, keeping the original order and
# dropping empty entries and duplicates (case-insensitive, like Windows paths).
function Merge-PathList {
    param(
        [string]$Path,
        [string[]]$Folders
    )

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    (@($Path -split ';') + $Folders |
        Where-Object { $_ -and $seen.Add($_) }) -join ';'
}

# Current session
$env:Path = Merge-PathList -Path $env:Path -Folders $folders

if (-not $StorePermanently) {
    Write-Host "Added $($folders.Count) folder(s) under '$scriptRoot' to PATH for this session only."
    return
}

# Persist for the current user
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$newPath = Merge-PathList -Path $userPath -Folders $folders
[Environment]::SetEnvironmentVariable('Path', $newPath, 'User')

Write-Host "Added $($folders.Count) folder(s) under '$scriptRoot' to PATH (current session and user PATH)."
