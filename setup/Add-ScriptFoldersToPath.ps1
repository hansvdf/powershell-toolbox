<#
.SYNOPSIS
Adds a folder and all its subfolders to PATH.

.DESCRIPTION
Adds the folder and every subfolder below it to PATH, so scripts in them
can be run by name from anywhere. Dot-folders (.git, .vscode, ...),
folders listed in -Exclude (by default 'docs') and everything inside them
are skipped. Works on Windows and macOS (and Linux).

By default, PATH is only updated for the current PowerShell session. Use
-StorePermanently to also save it, so new PowerShell sessions pick it up
too:
- Windows: the folders are added to the user PATH (registry).
- macOS/Linux: a marked block with the folder list is written to the
  current user's PowerShell profile for all hosts
  (~/.config/powershell/profile.ps1). Running the script again replaces
  that block; the rest of the profile is left alone.

Existing PATH entries keep their order; duplicates (case-insensitive) and
empty entries are removed.

Subfolders are collected when the script runs. Run it again after adding
new subfolders.

See docs/path-setup-macos.md for how PATH and the PowerShell profiles
work on macOS.

.PARAMETER Path
The folder to add. Defaults to the powershell-toolbox folder (the parent
of the folder this script is in).

.PARAMETER Exclude
Names of folders to skip, together with everything inside them, at any
depth. Wildcards are allowed (e.g. 'test*'). Defaults to 'docs'. Use
-Exclude @() to skip nothing except dot-folders, which are always skipped.

.PARAMETER StorePermanently
Also saves the folders, so they stay on PATH in new PowerShell sessions:
in the user PATH on Windows, in the PowerShell profile on macOS/Linux.
Without it, the folders are gone once this PowerShell window is closed.

.EXAMPLE
PS> ./setup/Add-ScriptFoldersToPath.ps1

Adds the powershell-toolbox folder and its subfolders to PATH for this
PowerShell session.

.EXAMPLE
PS> ./setup/Add-ScriptFoldersToPath.ps1 -Path 'C:\Scripts'

Adds C:\Scripts and its subfolders to PATH for this PowerShell session.

.EXAMPLE
PS> ./setup/Add-ScriptFoldersToPath.ps1 -Exclude 'docs', 'test*'

Adds the powershell-toolbox folder and its subfolders, except 'docs' and
any folder whose name starts with 'test'.

.EXAMPLE
PS> ./setup/Add-ScriptFoldersToPath.ps1 -StorePermanently

Adds the powershell-toolbox folder and its subfolders to PATH for this
session and saves them for new sessions.
#>

param(
    [ValidateScript({
        if (Test-Path -LiteralPath $_ -PathType Container) { return $true }
        throw "Folder '$_' does not exist."
    })]
    [string]$Path = (Split-Path -Parent $PSScriptRoot),

    [string[]]$Exclude = @('docs'),

    [switch]$StorePermanently
)

# $IsWindows does not exist in Windows PowerShell 5.1, so check the platform directly.
$onWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$separator = [IO.Path]::PathSeparator  # ';' on Windows, ':' on macOS/Linux

$scriptRoot = (Resolve-Path -LiteralPath $Path).ProviderPath.TrimEnd('\', '/')

# All subfolders, except dot-folders (.git, .vscode, ...), folders matching -Exclude,
# and anything inside them.
$skipPatterns = @('.*') + $Exclude
$folders = @($scriptRoot) + @(
    Get-ChildItem -LiteralPath $scriptRoot -Directory -Recurse |
        Where-Object {
            $relative = $_.FullName.Substring($scriptRoot.Length).TrimStart('\', '/')
            $skipped = foreach ($segment in $relative -split '[\\/]') {
                foreach ($pattern in $skipPatterns) {
                    if ($segment -like $pattern) { $segment }
                }
            }
            -not $skipped
        } |
        Select-Object -ExpandProperty FullName |
        Sort-Object
)

# Appends folders to a path list, keeping the original order and dropping
# empty entries and duplicates (case-insensitive).
function Merge-PathList {
    param(
        [string]$Path,
        [string[]]$Folders
    )

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    (@($Path -split [regex]::Escape($separator)) + $Folders |
        Where-Object { $_ -and $seen.Add($_) }) -join $separator
}

# Current session. $env:PATH works on every platform; on macOS/Linux, environment
# variable names are case-sensitive, so $env:Path would be a different variable.
$env:PATH = Merge-PathList -Path $env:PATH -Folders $folders

if (-not $StorePermanently) {
    Write-Host "Added $($folders.Count) folder(s) under '$scriptRoot' to PATH for this session only."
    return
}

if ($onWindows) {
    # Persist in the user PATH (registry).
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $newPath = Merge-PathList -Path $userPath -Folders $folders
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')

    Write-Host "Added $($folders.Count) folder(s) under '$scriptRoot' to PATH (current session and user PATH)."
    return
}

# macOS/Linux: there is no user PATH to save to, so write the folder list to the
# PowerShell profile that every PowerShell host loads for the current user.
$profilePath = $PROFILE.CurrentUserAllHosts
$newline = [Environment]::NewLine

# The markers include the folder, so blocks for different folders can coexist.
$beginMarker = "# >>> powershell-toolbox PATH: $scriptRoot >>>"
$endMarker = "# <<< powershell-toolbox PATH: $scriptRoot <<<"
$blockPattern = '(?s)' + [regex]::Escape($beginMarker) + '.*?' + [regex]::Escape($endMarker) + '(\r?\n)?'

$block = @(
    $beginMarker
    "# Added by Add-ScriptFoldersToPath.ps1 on $(Get-Date -Format 'yyyy-MM-dd')."
    '# Run that script again with -StorePermanently to update this list, or'
    '# Remove-ScriptFoldersFromPath.ps1 -StorePermanently to remove this block.'
    'foreach ($folder in @('
    $folders | ForEach-Object { "    '" + ($_ -replace "'", "''") + "'" }
    ')) {'
    '    if (($env:PATH -split [IO.Path]::PathSeparator) -notcontains $folder) {'
    '        $env:PATH += [IO.Path]::PathSeparator + $folder'
    '    }'
    '}'
    $endMarker
) -join $newline

$content = ''
if (Test-Path -LiteralPath $profilePath) {
    $content = [string](Get-Content -LiteralPath $profilePath -Raw)
}

$existing = [regex]::Match($content, $blockPattern)
if ($existing.Success) {
    # Replace the old block in place.
    $content = $content.Substring(0, $existing.Index) + $block + $newline +
        $content.Substring($existing.Index + $existing.Length)
    $action = 'Updated'
}
else {
    # Append, separated from existing content by a blank line.
    if ($content) {
        $content = $content.TrimEnd("`r", "`n") + $newline + $newline
    }
    $content += $block + $newline
    $action = 'Added'
}

New-Item -ItemType Directory -Path (Split-Path -Parent $profilePath) -Force | Out-Null
Set-Content -LiteralPath $profilePath -Value $content -NoNewline -Encoding utf8

Write-Host "Added $($folders.Count) folder(s) under '$scriptRoot' to PATH for this session."
Write-Host "$action the PATH block in '$profilePath', so new PowerShell sessions get them too."
