<#
.SYNOPSIS
Removes a folder and all its subfolders from PATH.

.DESCRIPTION
The opposite of Add-ScriptFoldersToPath.ps1. Removes every PATH entry
that is the folder itself or any folder below it. Because entries are
matched by location, this also removes subfolders that have since been
deleted or renamed. Matching is case-insensitive, like Windows paths.

By default, PATH is only updated for the current PowerShell session. Use
-StorePermanently to also remove the folders from the user PATH, so new
terminals no longer have them either. All other entries keep their order.

.PARAMETER Path
The folder to remove. Defaults to the powershell-toolbox folder (the
parent of the folder this script is in). The folder does not need to
exist anymore.

.PARAMETER StorePermanently
Also removes the folders from the user PATH. Without it, the user PATH is
not changed, so new terminals still have the folders on PATH.

.EXAMPLE
PS> .\setup\Remove-ScriptFoldersFromPath.ps1

Removes the powershell-toolbox folder and its subfolders from PATH for
this PowerShell session.

.EXAMPLE
PS> .\setup\Remove-ScriptFoldersFromPath.ps1 -Path 'C:\Scripts'

Removes C:\Scripts and its subfolders from PATH for this PowerShell
session.

.EXAMPLE
PS> .\setup\Remove-ScriptFoldersFromPath.ps1 -StorePermanently

Removes the powershell-toolbox folder and its subfolders from PATH for
this session and from the user PATH.
#>

param(
    [string]$Path = (Split-Path -Parent $PSScriptRoot),

    [switch]$StorePermanently
)

# The folder may no longer exist, so resolve it without Resolve-Path.
$scriptRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path).TrimEnd('\', '/')

# Removes entries that are $Root or below it from a ';'-separated path list.
# Returns the new list and how many entries were removed.
function Remove-PathListFolder {
    param(
        [string]$Path,
        [string]$Root
    )

    $kept = @()
    $removed = 0

    foreach ($entry in @($Path -split ';')) {
        if (-not $entry) { continue }

        $normalized = $entry.TrimEnd('\', '/')
        $isUnderRoot = $normalized -ieq $Root -or
            $normalized.StartsWith("$Root\", [System.StringComparison]::OrdinalIgnoreCase) -or
            $normalized.StartsWith("$Root/", [System.StringComparison]::OrdinalIgnoreCase)

        if ($isUnderRoot) { $removed++ } else { $kept += $entry }
    }

    [pscustomobject]@{ Path = $kept -join ';'; Removed = $removed }
}

# Current session
$session = Remove-PathListFolder -Path $env:Path -Root $scriptRoot
$env:Path = $session.Path

if (-not $StorePermanently) {
    Write-Host "Removed $($session.Removed) folder(s) under '$scriptRoot' from PATH for this session only."
    return
}

# Persist for the current user
$user = Remove-PathListFolder -Path ([Environment]::GetEnvironmentVariable('Path', 'User')) -Root $scriptRoot
if ($user.Removed -gt 0) {
    [Environment]::SetEnvironmentVariable('Path', $user.Path, 'User')
}

Write-Host "Removed $($session.Removed) folder(s) under '$scriptRoot' from the current session PATH and $($user.Removed) from the user PATH."
