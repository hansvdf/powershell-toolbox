<#
.SYNOPSIS
    Lists the Power BI workspace, report and semantic model behind each PBIX file in a folder.

.DESCRIPTION
    Reads the 'Connections' entry inside each PBIX file to find the report ID, semantic model ID
    and workspace ID, then looks up their names through the Power BI REST API.

    Authentication uses your existing Azure CLI sign-in, so run this first:
        az login --allow-no-subscriptions

    Throttled API calls (HTTP 429) and temporary outages (HTTP 503) are retried automatically,
    honouring the Retry-After header when the service sends one.

.PARAMETER FolderPath
    Folder to scan for PBIX files. Defaults to the current folder.

.PARAMETER Recurse
    Also scan subfolders.

.PARAMETER CsvPath
    Optional path of a CSV file to export the results to.

.PARAMETER PassThru
    Output the result objects instead of a formatted table, so they can be piped or filtered.

.EXAMPLE
    .\Scan-PBIXReports.ps1 -FolderPath C:\Reports -Recurse

.EXAMPLE
    .\Scan-PBIXReports.ps1 -FolderPath C:\Reports -CsvPath .\pbix-scan.csv

.EXAMPLE
    .\Scan-PBIXReports.ps1 -FolderPath C:\Reports -PassThru | Where-Object Status -ne 'OK'

.OUTPUTS
    A formatted table by default; PSCustomObject per PBIX file with -PassThru.
#>
#Requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$FolderPath = ".",
    [switch]$Recurse,
    [string]$CsvPath,
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$folder = (Resolve-Path -LiteralPath $FolderPath).Path
$files = @(Get-ChildItem -LiteralPath $folder -Filter '*.pbix' -File -Recurse:$Recurse)
if ($files.Count -eq 0) {
    Write-Warning "No PBIX files found in: $folder"
    return
}

# Authenticate once, using an existing Azure CLI sign-in.
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI (az) not found. Install it, then run az login --allow-no-subscriptions.'
}
# Discard stderr so az warnings (e.g. upgrade notices) neither abort the script nor end up in the token.
$accessToken = & az account get-access-token --resource 'https://analysis.windows.net/powerbi/api' --query accessToken -o tsv 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace("$accessToken")) {
    throw 'Could not obtain a Power BI access token. Run az login --allow-no-subscriptions first.'
}
$headers = @{ Authorization = "Bearer $("$accessToken".Trim())" }
$apiRoot = 'https://api.powerbi.com/v1.0/myorg'
$apiCache = @{}
$maxAttempts = 5
$maxDelaySeconds = 60

# Seconds to wait before retrying: the Retry-After header if present, else exponential backoff.
function Get-RetryDelaySeconds {
    param($Response, [int]$Attempt)
    $retryAfter = $null
    # PowerShell 7: HttpResponseMessage with typed headers.
    try { $retryAfter = $Response.Headers.RetryAfter.Delta.TotalSeconds } catch { }
    # Windows PowerShell 5.1: HttpWebResponse with a WebHeaderCollection.
    if (-not $retryAfter) { try { $retryAfter = [double]$Response.Headers['Retry-After'] } catch { } }
    if (-not $retryAfter -or $retryAfter -le 0) { $retryAfter = [math]::Pow(2, $Attempt) }
    return [int][math]::Min([math]::Ceiling($retryAfter), $maxDelaySeconds)
}

function Get-CachedApiResult {
    param([string]$Url, [hashtable]$Cache, [hashtable]$Headers)
    if (-not $Cache.ContainsKey($Url)) {
        for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
            try {
                $data = Invoke-RestMethod -Uri $Url -Method Get -Headers $Headers -ErrorAction Stop
                $Cache[$Url] = @{ Data = $data; Error = $null }
                break
            }
            catch {
                $response = $_.Exception.Response
                $statusCode = if ($null -ne $response) { [int]$response.StatusCode } else { 0 }
                if ($statusCode -in 429, 503 -and $attempt -lt $maxAttempts) {
                    $delay = Get-RetryDelaySeconds -Response $response -Attempt $attempt
                    Write-Warning "HTTP $statusCode from Power BI API; retrying in $delay s (attempt $attempt of $maxAttempts)."
                    Start-Sleep -Seconds $delay
                    continue
                }
                $Cache[$Url] = @{ Data = $null; Error = $_.Exception.Message }
                break
            }
        }
    }
    return $Cache[$Url]
}

# Looks up a dataset or report. Tries the PBIX's workspace first, then falls back to the
# workspace-less endpoint, which resolves items in other workspaces you can access
# (e.g. a thin report whose semantic model lives in a different workspace).
function Get-PbiItem {
    param([string]$Kind, [string]$Id, [string]$WorkspaceId)
    $first = $null
    if ($WorkspaceId) {
        $first = Get-CachedApiResult -Url "$apiRoot/groups/$WorkspaceId/$Kind/$Id" -Cache $apiCache -Headers $headers
        if (-not $first.Error) { return $first }
    }
    $fallback = Get-CachedApiResult -Url "$apiRoot/$Kind/$Id" -Cache $apiCache -Headers $headers
    if (-not $fallback.Error -or $null -eq $first) { return $fallback }
    return $first   # both failed: the workspace-scoped error is the more meaningful one
}

$results = foreach ($file in $files) {
    Write-Verbose "Scanning $($file.FullName)"
    $zip = $null
    $reader = $null
    $item = [ordered]@{
        File = $file.FullName.Substring($folder.Length).TrimStart('\', '/')
        WorkspaceName = $null
        ReportName = $null
        SemanticModelName = $null
        ConnectionType = $null
        ReportId = $null
        SemanticModelId = $null
        WorkspaceId = $null
        Status = 'OK'
    }
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($file.FullName)
        $entry = $zip.GetEntry('Connections')
        if ($null -eq $entry) {
            $item.Status = 'No Connections entry (likely a local model that was never published)'
        }
        else {
            $reader = [System.IO.StreamReader]::new($entry.Open())
            $json = $reader.ReadToEnd() | ConvertFrom-Json

            # Only the first connection/artifact is used; thin reports have exactly one.
            $connection = @($json.Connections | Where-Object { $null -ne $_ } | Select-Object -First 1)
            $artifact = @($json.RemoteArtifacts | Where-Object { $null -ne $_ } | Select-Object -First 1)
            if ($connection.Count -gt 0) {
                $item.ConnectionType = $connection[0].ConnectionType
                $item.SemanticModelId = $connection[0].PbiModelDatabaseName
            }
            if ($artifact.Count -gt 0) {
                if ($artifact[0].DatasetId) { $item.SemanticModelId = $artifact[0].DatasetId }
                $item.ReportId = $artifact[0].ReportId
            }
            $item.WorkspaceId = $json.OriginalWorkspaceObjectId
        }
    }
    catch {
        $item.Status = "PBIX: $($_.Exception.Message)"
    }
    finally {
        if ($null -ne $reader) { $reader.Dispose() }
        if ($null -ne $zip) { $zip.Dispose() }
    }

    if ($item.Status -eq 'OK') {
        $issues = @()
        if ($item.WorkspaceId) {
            # There is no GET /groups/{id}; filter the workspace list instead.
            $filter = [uri]::EscapeDataString("id eq '$($item.WorkspaceId)'")
            $response = Get-CachedApiResult -Url "$apiRoot/groups?`$filter=$filter" -Cache $apiCache -Headers $headers
            if ($response.Error) { $issues += "Workspace lookup: $($response.Error)" }
            elseif (@($response.Data.value).Count -eq 0) { $issues += 'Workspace not found (no access, or a personal workspace)' }
            else { $item.WorkspaceName = @($response.Data.value)[0].name }
        }
        else { $issues += 'Workspace ID not found' }

        if ($item.SemanticModelId) {
            $response = Get-PbiItem -Kind 'datasets' -Id $item.SemanticModelId -WorkspaceId $item.WorkspaceId
            if ($response.Error) { $issues += "Semantic model lookup: $($response.Error)" }
            else { $item.SemanticModelName = $response.Data.name }
        }
        else { $issues += 'Semantic model ID not found' }

        if ($item.ReportId) {
            $response = Get-PbiItem -Kind 'reports' -Id $item.ReportId -WorkspaceId $item.WorkspaceId
            if ($response.Error) { $issues += "Report lookup: $($response.Error)" }
            else { $item.ReportName = $response.Data.name }
        }
        else { $issues += 'Report ID not found' }

        if ($issues.Count -gt 0) { $item.Status = $issues -join '; ' }
    }
    [PSCustomObject]$item
}

if ($CsvPath) {
    $results | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "Results exported to: $CsvPath" -ForegroundColor Green
}
if ($PassThru) {
    $results
}
else {
    $results | Format-Table File, WorkspaceName, ReportName, SemanticModelName, Status -AutoSize -Wrap
}
