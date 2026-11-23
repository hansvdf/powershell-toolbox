<#
.SYNOPSIS
Shows the name (SSID) of the Wi-Fi network you are connected to.

.DESCRIPTION
Reads the output of 'netsh wlan show interfaces' and returns the SSID of
each connected Wi-Fi adapter, one per line. Shows a warning, and returns
nothing, when no Wi-Fi network is connected or Wi-Fi is unavailable.

Works on Windows only, because it relies on netsh. On macOS and Linux it
stops with an error.

.EXAMPLE
.\Get-WifiSsid.ps1

Shows the name of the current Wi-Fi network.

.EXAMPLE
if ((.\Get-WifiSsid.ps1) -eq 'HomeNetwork') { 'At home' }

Uses the result in a condition.

.OUTPUTS
System.String. One SSID per connected Wi-Fi adapter.
#>
#Requires -Version 5.1

[CmdletBinding()]
param()

# $IsWindows only exists in PowerShell 7+; Windows PowerShell 5.1 always runs on Windows.
if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) {
    throw 'Get-WifiSsid.ps1 only works on Windows, because it relies on netsh.'
}

$output = netsh wlan show interfaces 2>&1
if ($LASTEXITCODE -ne 0) {
    # netsh fails when there is no Wi-Fi adapter or the WLAN service is not running.
    Write-Warning "Wi-Fi is not available: $(($output | Out-String).Trim())"
    return
}

# '^\s*SSID' matches the SSID line but not the BSSID line.
$ssids = @($output | Select-String '^\s*SSID\s*:\s*(.+)$' |
    ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() })

if ($ssids.Count -eq 0) {
    Write-Warning 'Not connected to a Wi-Fi network.'
    return
}
$ssids
