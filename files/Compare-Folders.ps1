<#
.SYNOPSIS
Compares the file names in two folders.

.DESCRIPTION
Lists file names found only in Folder A, only in Folder B, or in both.
Compares file names only. With -Recurse, files with the same name in
different subfolders are treated as the same name.

.PARAMETER FolderA
Path to the first folder.

.PARAMETER FolderB
Path to the second folder.

.PARAMETER Recurse
Includes files in subfolders. By default, only the two folder roots
are compared.

.EXAMPLE
PS> .\Compare-Folders.ps1 -FolderA 'C:\Releases\R26SP05' -FolderB 'C:\Releases\R26SP05BF01'

Compares files directly inside the two release folders.

.EXAMPLE
PS> .\Compare-Folders.ps1 -FolderA 'C:\Releases\R26SP05' -FolderB 'C:\Releases\R26SP05BF01' -Recurse

Compares file names across both release folders and all their subfolders.
#>

param(
    [Parameter(Mandatory)]
    [string]$FolderA,

    [Parameter(Mandatory)]
    [string]$FolderB,

    [switch]$Recurse
)

$namesA = @(Get-ChildItem -LiteralPath $FolderA -File -Force -Recurse:$Recurse -ErrorAction Stop |
    Select-Object -ExpandProperty Name | Sort-Object -Unique)

$namesB = @(Get-ChildItem -LiteralPath $FolderB -File -Force -Recurse:$Recurse -ErrorAction Stop |
    Select-Object -ExpandProperty Name | Sort-Object -Unique)

'Only in Folder A'
$namesA | Where-Object { $_ -notin $namesB }

'Only in Folder B'
$namesB | Where-Object { $_ -notin $namesA }

'In both folders'
$namesA | Where-Object { $_ -in $namesB }