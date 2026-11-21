$scriptRoot = 'C:\Scripts'

# All subfolders, except dot-folders (.git, .vscode, ...) and anything inside them.
$folders = @($scriptRoot) + @(
    Get-ChildItem -LiteralPath $scriptRoot -Directory -Recurse |
        Where-Object {
            $relative = $_.FullName.Substring($scriptRoot.Length).TrimStart('\')
            -not ($relative -split '\\' | Where-Object { $_ -like '.*' })
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

# Persist for the current user
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$newPath = Merge-PathList -Path $userPath -Folders $folders
[Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
