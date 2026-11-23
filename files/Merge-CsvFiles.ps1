<#
.SYNOPSIS
Merges CSV files into one file, with the source file name in front of every row.

.DESCRIPTION
Combines the rows of all CSV files in a folder into one output file. Each
row gets an extra first column with the name of the file it came from.
With -Recurse, that column holds the path relative to -Path instead
(e.g. 'sub\data.csv').

The rows are copied as they are. Only the file name column is added, and
it is quoted when the name contains the delimiter or a quote. A row whose
quoted value spans several lines gets the file name only once, at its
start. Empty lines are left out.

Each input file is read in its own encoding: UTF-8 or UTF-16 with a byte
order mark, UTF-8 without one, or otherwise the Windows ANSI code page
(what Excel uses for a plain 'CSV' save). The output is UTF-8 with a byte
order mark, so Excel shows special characters such as é and € correctly.

The output file is never read as one of the inputs, and neither is a
merged.csv directly in -Path (the default output of an earlier run), so
rows are never merged twice. An existing output file is replaced.

.PARAMETER Path
The folder with the CSV files. Defaults to the current folder.

.PARAMETER OutFile
The file to write the merged rows to. Defaults to 'merged.csv' in -Path.

.PARAMETER Filter
Which files to merge. Defaults to '*.csv'.

.PARAMETER Recurse
Also merges the files in subfolders.

.PARAMETER Delimiter
The character that separates the columns. Defaults to ';', which is what
Excel uses with Belgian and Dutch regional settings.

.PARAMETER HasHeader
Use this when every file starts with a header row. The output then starts
with one header row, taken from the first file with 'SourceFile' in front,
and the header rows of the other files are left out. Without -HasHeader,
every line is treated as data and the output has no header row.

.EXAMPLE
PS> .\Merge-CsvFiles.ps1

Merges all CSV files in the current folder into merged.csv.

.EXAMPLE
PS> .\Merge-CsvFiles.ps1 -Path D:\Exports -OutFile D:\all-exports.csv -Recurse

Merges the CSV files in D:\Exports and its subfolders into D:\all-exports.csv.

.EXAMPLE
PS> .\Merge-CsvFiles.ps1 -Delimiter ',' -HasHeader

Merges comma-separated files that each start with a header row.

.EXAMPLE
PS> .\Merge-CsvFiles.ps1 -WhatIf

Shows which files would be merged, without writing the output file.
#>
#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$Path = '.',

    [string]$OutFile,

    [string]$Filter = '*.csv',

    [switch]$Recurse,

    [ValidateNotNull()]
    [char]$Delimiter = ';',

    [switch]$HasHeader
)

$root = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath.TrimEnd('\', '/')
$defaultOutPath = Join-Path $root 'merged.csv'
if (-not $OutFile) { $OutFile = $defaultOutPath }
$outPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutFile)

# Never read the output file, nor a merged.csv left in the folder by an earlier
# run with the default output, so rows are never merged twice.
$files = @(Get-ChildItem -LiteralPath "$root$([IO.Path]::DirectorySeparatorChar)" -Filter $Filter -File -Recurse:$Recurse -ErrorAction Stop |
    Where-Object { $_.FullName -ne $outPath -and $_.FullName -ne $defaultOutPath } |
    Sort-Object FullName)

if ($files.Count -eq 0) {
    Write-Warning "No files matching '$Filter' found in: $root"
    return
}

# Reads a text file in the encoding it was saved in (see the help above).
function Read-TextFile {
    param([string]$LiteralPath)
    $bytes = [IO.File]::ReadAllBytes($LiteralPath)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
    }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        return [Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2)
    }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        return [Text.Encoding]::BigEndianUnicode.GetString($bytes, 2, $bytes.Length - 2)
    }
    try {
        # Strict UTF-8: throws on bytes that aren't valid UTF-8, e.g. an ANSI-encoded 'é'.
        return [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
    }
    catch {
        $ansi = [Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage
        return [Text.Encoding]::GetEncoding($ansi).GetString($bytes)
    }
}

# Splits the text into CSV rows. A quoted value can contain line breaks, so a row
# continues onto the next line while it has an odd number of quote characters.
function Split-CsvRow {
    param([string]$Text, [string]$FileName)
    $row = $null
    $quotes = 0
    foreach ($line in $Text -split '\r?\n') {
        if ($null -eq $row) {
            if ($line -eq '') { continue }   # skip empty lines between rows
            $row = $line
        }
        else {
            $row += "`r`n$line"
        }
        $quotes += ($line.Length - $line.Replace('"', '').Length)
        if ($quotes % 2 -eq 0) {
            $row
            $row = $null
            $quotes = 0
        }
    }
    if ($null -ne $row) {
        Write-Warning "Unclosed quote at the end of $FileName; its last row may be incomplete."
        $row
    }
}

# Quotes a value when it contains the delimiter, a quote or a line break.
function ConvertTo-CsvValue {
    param([string]$Value)
    if ($Value.IndexOfAny([char[]]@($Delimiter, '"', "`r", "`n")) -ge 0) {
        return '"' + $Value.Replace('"', '""') + '"'
    }
    return $Value
}

$names = foreach ($file in $files) {
    if ($Recurse) { $file.FullName.Substring($root.Length + 1) } else { $file.Name }
}

if ($WhatIfPreference) {
    foreach ($name in $names) { [void]$PSCmdlet.ShouldProcess($name, "Merge into $outPath") }
    return
}

$outFolder = Split-Path -Parent $outPath
if (-not (Test-Path -LiteralPath $outFolder)) { New-Item -ItemType Directory -Path $outFolder | Out-Null }
if (Test-Path -LiteralPath $outPath) { Write-Verbose "Replacing existing file: $outPath" }

$writer = [IO.StreamWriter]::new($outPath, $false, [Text.UTF8Encoding]::new($true))
$rowCount = 0
$headerWritten = $false
try {
    for ($i = 0; $i -lt $files.Count; $i++) {
        $name = @($names)[$i]
        Write-Verbose "Merging $name"
        $prefix = (ConvertTo-CsvValue $name) + $Delimiter
        $isFirstRow = $true
        foreach ($row in Split-CsvRow -Text (Read-TextFile $files[$i].FullName) -FileName $name) {
            if ($HasHeader -and $isFirstRow) {
                $isFirstRow = $false
                if (-not $headerWritten) {
                    $writer.Write("SourceFile$Delimiter$row`r`n")
                    $headerWritten = $true
                }
                continue
            }
            $writer.Write("$prefix$row`r`n")
            $rowCount++
        }
    }
}
finally {
    $writer.Dispose()
}

# Write-Host, so the summary isn't part of the output when piping.
Write-Host "Merged $($files.Count) files, $rowCount rows into: $outPath"
