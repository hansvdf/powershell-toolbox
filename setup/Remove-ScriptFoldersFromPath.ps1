<#
.SYNOPSIS
Removes a folder and all its subfolders from PATH.

.DESCRIPTION
The opposite of Add-ScriptFoldersToPath.ps1. Removes every PATH entry
that is the folder itself or any folder below it. Because entries are
matched by location, this also removes subfolders that have since been
deleted or renamed. Matching is case-insensitive. Works on Windows and
macOS (and Linux).

By default, PATH is only updated for the current PowerShell session. Use
-StorePermanently to also undo what Add-ScriptFoldersToPath.ps1
-StorePermanently saved:
- Windows: the folders are removed from the user PATH (registry).
- macOS/Linux: the marked PATH block for this folder is removed from the
  PowerShell profile (~/.config/powershell/profile.ps1). The rest of the
  profile is left alone; if nothing else is in it, the file is deleted.

All other PATH entries keep their order.

.PARAMETER Path
The folder to remove. Defaults to the powershell-toolbox folder (the
parent of the folder this script is in). The folder does not need to
exist anymore.

.PARAMETER StorePermanently
Also removes the saved folders: from the user PATH on Windows, from the
PowerShell profile on macOS/Linux. Without it, new PowerShell sessions
still have the folders on PATH.

.EXAMPLE
PS> ./setup/Remove-ScriptFoldersFromPath.ps1

Removes the powershell-toolbox folder and its subfolders from PATH for
this PowerShell session.

.EXAMPLE
PS> ./setup/Remove-ScriptFoldersFromPath.ps1 -Path 'C:\Scripts'

Removes C:\Scripts and its subfolders from PATH for this PowerShell
session.

.EXAMPLE
PS> ./setup/Remove-ScriptFoldersFromPath.ps1 -StorePermanently

Removes the powershell-toolbox folder and its subfolders from PATH for
this session and from the saved PATH.
#>

param(
    [string]$Path = (Split-Path -Parent $PSScriptRoot),

    [switch]$StorePermanently
)

# $IsWindows does not exist in Windows PowerShell 5.1, so check the platform directly.
$onWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$separator = [IO.Path]::PathSeparator  # ';' on Windows, ':' on macOS/Linux

# The folder may no longer exist, so resolve it without Resolve-Path.
$scriptRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path).TrimEnd('\', '/')

# Removes entries that are $Root or below it from a path list.
# Returns the new list and how many entries were removed.
function Remove-PathListFolder {
    param(
        [string]$Path,
        [string]$Root
    )

    $kept = @()
    $removed = 0

    foreach ($entry in @($Path -split [regex]::Escape($separator))) {
        if (-not $entry) { continue }

        $normalized = $entry.TrimEnd('\', '/')
        $isUnderRoot = $normalized -ieq $Root -or
            $normalized.StartsWith("$Root\", [System.StringComparison]::OrdinalIgnoreCase) -or
            $normalized.StartsWith("$Root/", [System.StringComparison]::OrdinalIgnoreCase)

        if ($isUnderRoot) { $removed++ } else { $kept += $entry }
    }

    [pscustomobject]@{ Path = $kept -join $separator; Removed = $removed }
}

# Current session. $env:PATH works on every platform; on macOS/Linux, environment
# variable names are case-sensitive, so $env:Path would be a different variable.
$session = Remove-PathListFolder -Path $env:PATH -Root $scriptRoot
$env:PATH = $session.Path

if (-not $StorePermanently) {
    Write-Host "Removed $($session.Removed) folder(s) under '$scriptRoot' from PATH for this session only."
    return
}

if ($onWindows) {
    # Remove from the user PATH (registry).
    $user = Remove-PathListFolder -Path ([Environment]::GetEnvironmentVariable('Path', 'User')) -Root $scriptRoot
    if ($user.Removed -gt 0) {
        [Environment]::SetEnvironmentVariable('Path', $user.Path, 'User')
    }

    Write-Host "Removed $($session.Removed) folder(s) under '$scriptRoot' from the current session PATH and $($user.Removed) from the user PATH."
    return
}

# macOS/Linux: remove the block that Add-ScriptFoldersToPath.ps1 wrote to the profile.
Write-Host "Removed $($session.Removed) folder(s) under '$scriptRoot' from PATH for this session."

$profilePath = $PROFILE.CurrentUserAllHosts
$beginMarker = "# >>> powershell-toolbox PATH: $scriptRoot >>>"
$endMarker = "# <<< powershell-toolbox PATH: $scriptRoot <<<"
$blockPattern = '(?s)' + [regex]::Escape($beginMarker) + '.*?' + [regex]::Escape($endMarker) + '(\r?\n)?'

$content = ''
if (Test-Path -LiteralPath $profilePath) {
    $content = [string](Get-Content -LiteralPath $profilePath -Raw)
}

$existing = [regex]::Match($content, $blockPattern)
if (-not $existing.Success) {
    Write-Host "No PATH block for '$scriptRoot' found in '$profilePath'; nothing to remove there."
    return
}

$content = $content.Substring(0, $existing.Index) + $content.Substring($existing.Index + $existing.Length)

if ($content.Trim()) {
    # Drop the blank line(s) left at the end where the block was.
    $content = $content.TrimEnd("`r", "`n") + [Environment]::NewLine
    Set-Content -LiteralPath $profilePath -Value $content -NoNewline -Encoding utf8
    Write-Host "Removed the PATH block from '$profilePath'."
}
else {
    Remove-Item -LiteralPath $profilePath
    Write-Host "Removed the PATH block from '$profilePath'; the profile was otherwise empty, so it was deleted."
}
