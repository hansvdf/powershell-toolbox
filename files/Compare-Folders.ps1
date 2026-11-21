<#
.SYNOPSIS
Compares the file names in two folders.

.DESCRIPTION
Shows a table with one row per file and a Yes/No column for each folder,
telling whether that file exists in Folder A and in Folder B. Compares
file names only, not contents.

The two Yes/No columns are named after the folders being compared. When
both folders have the same name, ' (A)' and ' (B)' are added to tell
them apart.

With -Recurse, the File column shows the path relative to the folder
(e.g. 'sub\file.txt'), and a file only counts as present in both folders
when it is in the same subfolder in each.

The rows are objects, so they can be filtered, sorted or exported (see
the examples).

.PARAMETER FolderA
Path to the first folder.

.PARAMETER FolderB
Path to the second folder.

.PARAMETER Recurse
Includes files in subfolders. By default, only the two folder roots
are compared.

.PARAMETER DifferencesOnly
Only shows files that are missing from one of the two folders. Files
that exist in both are left out. Shows 'No differences found.' when
both folders contain the same files.

.EXAMPLE
PS> .\Compare-Folders.ps1 -FolderA 'C:\Releases\R26SP05' -FolderB 'C:\Releases\R26SP05BF01'

File        R26SP05 R26SP05BF01
----        ------- -----------
app.exe     Yes     Yes
fix.dll     No      Yes

Compares files directly inside the two release folders.

.EXAMPLE
PS> .\Compare-Folders.ps1 -FolderA 'C:\Releases\R26SP05' -FolderB 'C:\Releases\R26SP05BF01' -Recurse

Compares both release folders including all their subfolders.

.EXAMPLE
PS> .\Compare-Folders.ps1 -FolderA 'C:\Releases\R26SP05' -FolderB 'C:\Releases\R26SP05BF01' -Recurse -DifferencesOnly

File        R26SP05 R26SP05BF01
----        ------- -----------
fix.dll     No      Yes
old.dll     Yes     No

Shows only the files that exist in one of the two folders.

.EXAMPLE
PS> .\Compare-Folders.ps1 -FolderA .\old -FolderB .\new | Export-Csv .\comparison.csv -NoTypeInformation

Saves the comparison to a CSV file, e.g. to open in Excel.
#>

param(
    [Parameter(Mandatory)]
    [string]$FolderA,

    [Parameter(Mandatory)]
    [string]$FolderB,

    [switch]$Recurse,

    [switch]$DifferencesOnly
)

$rootA = (Resolve-Path -LiteralPath $FolderA -ErrorAction Stop).ProviderPath.TrimEnd('\', '/')
$rootB = (Resolve-Path -LiteralPath $FolderB -ErrorAction Stop).ProviderPath.TrimEnd('\', '/')

# Column titles: the folder names, made unique if needed.
$columnA = Split-Path -Leaf $rootA
$columnB = Split-Path -Leaf $rootB
if (-not $columnA) { $columnA = $rootA }  # e.g. a drive root like 'C:'
if (-not $columnB) { $columnB = $rootB }
if ($columnA -eq $columnB -or 'File' -in $columnA, $columnB) {
    $columnA += ' (A)'
    $columnB += ' (B)'
}

# Returns the paths of all files in $Root, relative to $Root (e.g. 'sub\file.txt').
function Get-RelativeFilePath {
    param(
        [string]$Root
    )

    Get-ChildItem -LiteralPath "$Root$([IO.Path]::DirectorySeparatorChar)" -File -Force -Recurse:$Recurse -ErrorAction Stop |
        ForEach-Object { $_.FullName.Substring($Root.Length + 1) }
}

$namesA = @(Get-RelativeFilePath -Root $rootA)
$namesB = @(Get-RelativeFilePath -Root $rootB)

# One row per file path found in either folder (case-insensitive, like Windows).
$rows = @($namesA + $namesB | Sort-Object -Unique | ForEach-Object {
    $inA = $_ -in $namesA
    $inB = $_ -in $namesB

    if ($DifferencesOnly -and $inA -and $inB) { return }

    [pscustomobject][ordered]@{
        File     = $_
        $columnA = if ($inA) { 'Yes' } else { 'No' }
        $columnB = if ($inB) { 'Yes' } else { 'No' }
    }
})

if ($DifferencesOnly -and $rows.Count -eq 0) {
    # Write-Host, so the message isn't part of the output when piping or exporting.
    Write-Host 'No differences found.'
}

$rows
