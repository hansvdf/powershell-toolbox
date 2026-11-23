<#
.SYNOPSIS
Copies the files from the subfolders of a folder into one folder.

.DESCRIPTION
Collects files from all subfolders of -Path, at any depth, and copies
them side by side into -Destination. Files directly in -Path are not
copied, as they are not in a subfolder.

Use -FolderName to only take files from folders with a given name, such
as every 'ARCHIVE' folder. Only the folders below -Path are checked, so
it doesn't matter what the folders above -Path are called.

Files with the same name never silently overwrite each other:
- When two subfolders contain a file with the same name, the first one
  (in alphabetical order of their paths) is copied and the others are
  skipped with a warning.
- When the destination already has a file with that name, the file is
  skipped with a warning, unless you add -Overwrite. A file that is
  identical to an earlier copy (same size and last-modified time) is
  skipped without a warning, so running the script again is quiet.

Ends with a summary of how many files were copied and skipped. Use
-WhatIf to see what would be copied without copying anything.

.PARAMETER Path
The folder whose subfolders are searched. Defaults to the current folder.

.PARAMETER Destination
The folder the files are copied to. Defaults to -Path. Created if it
doesn't exist yet.

.PARAMETER FolderName
Only copy files that are inside a folder with one of these names, at any
depth below -Path. Not case-sensitive. Leave it out to copy the files
from all subfolders.

.PARAMETER Overwrite
Replace files that already exist in the destination, instead of skipping
them. Files with the same name from two subfolders are still skipped.

.EXAMPLE
PS> .\Copy-SubfolderFiles.ps1 -FolderName ARCHIVE

Copies the files from every ARCHIVE folder below the current folder into
the current folder.

.EXAMPLE
PS> .\Copy-SubfolderFiles.ps1 -FolderName PROCESSED, ERROR

Copies the files from every PROCESSED and ERROR folder.

.EXAMPLE
PS> .\Copy-SubfolderFiles.ps1 -Path D:\Data -Destination D:\Flat

Copies the files from all subfolders of D:\Data into D:\Flat.

.EXAMPLE
PS> .\Copy-SubfolderFiles.ps1 -FolderName ARCHIVE -WhatIf

Shows which files would be copied, without copying anything.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$Path = '.',

    [string]$Destination,

    [string[]]$FolderName,

    [switch]$Overwrite
)

$root = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath.TrimEnd('\', '/')
$target = if ($Destination) {
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination).TrimEnd('\', '/')
}
else { $root }

if ((Test-Path -LiteralPath $target) -and -not (Test-Path -LiteralPath $target -PathType Container)) {
    throw "Destination is a file, not a folder: $target"
}

$separators = [char[]]@('\', '/')
$files = Get-ChildItem -LiteralPath "$root$([IO.Path]::DirectorySeparatorChar)" -File -Recurse -ErrorAction Stop |
    Where-Object {
        $folder = $_.DirectoryName.TrimEnd($separators)
        # Only files in subfolders, and never files that are already in the destination.
        if ($folder -eq $root -or $folder -eq $target) { return $false }
        if (-not $FolderName) { return $true }
        # Check only the folder names below $root, e.g. 'A\ARCHIVE' -> 'A', 'ARCHIVE'.
        $relativeFolders = $folder.Substring($root.Length + 1).Split($separators)
        @($relativeFolders | Where-Object { $_ -in $FolderName }).Count -gt 0
    } |
    Sort-Object FullName

if (-not $files) {
    Write-Warning 'No files found to copy.'
    return
}

if (-not (Test-Path -LiteralPath $target) -and $PSCmdlet.ShouldProcess($target, 'Create folder')) {
    New-Item -ItemType Directory -Path $target -ErrorAction Stop | Out-Null
}

$copied = 0
$unchanged = 0
$skipped = 0
$failed = 0
# File names handled in this run, so a second file with the same name is never copied over the first.
$namesSeen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

foreach ($file in $files) {
    $targetFile = Join-Path $target $file.Name
    $relativePath = $file.FullName.Substring($root.Length + 1)

    if (-not $namesSeen.Add($file.Name)) {
        Write-Warning "Skipped $relativePath - another file named '$($file.Name)' was already copied in this run."
        $skipped++
        continue
    }

    $existing = Get-Item -LiteralPath $targetFile -ErrorAction SilentlyContinue
    if ($existing) {
        if ($existing.Length -eq $file.Length -and $existing.LastWriteTimeUtc -eq $file.LastWriteTimeUtc) {
            Write-Verbose "Unchanged: $relativePath"
            $unchanged++
            continue
        }
        if (-not $Overwrite) {
            Write-Warning "Skipped $relativePath - '$($file.Name)' already exists in the destination. Use -Overwrite to replace it."
            $skipped++
            continue
        }
    }

    if ($PSCmdlet.ShouldProcess($relativePath, "Copy to $target")) {
        try {
            Copy-Item -LiteralPath $file.FullName -Destination $targetFile -Force:$Overwrite -ErrorAction Stop
            Write-Verbose "Copied: $relativePath"
            $copied++
        }
        catch {
            Write-Error "Failed to copy $relativePath - $($_.Exception.Message)" -ErrorAction Continue
            $failed++
        }
    }
}

# Write-Host, so the summary isn't part of the output when piping.
$summary = "Copied: $copied, unchanged: $unchanged, skipped: $skipped, failed: $failed."
if ($WhatIfPreference) { $summary = "WhatIf - nothing was copied. Skipped: $skipped, unchanged: $unchanged." }
Write-Host $summary
