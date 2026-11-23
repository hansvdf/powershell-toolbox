<#
.SYNOPSIS
Lists all scripts in the toolbox with a one-line description.

.DESCRIPTION
Shows a table with every PowerShell script in the toolbox and a short
description of what it does. The description is the .SYNOPSIS line from
the script's built-in help, so it stays up to date when a script changes.

The scripts are only read, never run. Dot-folders such as .git are
skipped. Scripts without a synopsis show '(no description)'.

The rows are objects, so they can be filtered or sorted (see the examples).

.PARAMETER Path
The folder to list the scripts of, including its subfolders. Defaults to
the toolbox this script is part of.

.EXAMPLE
PS> .\Get-ToolboxScripts.ps1

Script                           Description
------                           -----------
Compare-Folders.ps1              Compares the file names in two folders.
Get-WifiSsid.ps1                 Shows the name (SSID) of the Wi-Fi network you are connected to.
...

.EXAMPLE
PS> .\Get-ToolboxScripts.ps1 | Where-Object Description -like '*CSV*'

Shows only the scripts whose description mentions CSV.
#>
#Requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$Path = (Split-Path -Parent $PSScriptRoot)
)

$root = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath.TrimEnd('\', '/')

Get-ChildItem -LiteralPath "$root$([IO.Path]::DirectorySeparatorChar)" -Filter '*.ps1' -File -Recurse |
    Where-Object {
        # Skip scripts inside dot-folders such as .git or .claude.
        $relativeFolders = $_.DirectoryName.Substring($root.Length).Split([char[]]@('\', '/'))
        -not ($relativeFolders | Where-Object { $_.StartsWith('.') })
    } |
    Sort-Object Name |
    ForEach-Object {
        # Parse the file instead of running it; GetHelpContent reads the comment-based help.
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$parseErrors)
        $synopsis = $ast.GetHelpContent().Synopsis
        $description = if ($synopsis) { ($synopsis -replace '\s+', ' ').Trim() } else { '(no description)' }

        [pscustomobject][ordered]@{
            Script      = $_.Name
            Description = $description
        }
    }
