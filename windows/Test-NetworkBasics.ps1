<#
.SYNOPSIS
    Step-by-step connectivity check for "the internet is not working" tickets.

.DESCRIPTION
    Tests each layer in order, so the first FAIL tells you where the problem is:
      1. The PC has an IP address (not 169.254.x.x)
      2. The default gateway (router) answers
      3. An outside IP answers (the internet link works)
      4. DNS resolves a name
      5. A website answers on HTTPS (port 443)
    Read-only. Runs without admin rights.

.PARAMETER PublicIp
    Outside IP used for test 3. Default: 1.1.1.1

.PARAMETER TestHost
    Name used for the DNS and HTTPS tests. Default: www.microsoft.com

.EXAMPLE
    .\Test-NetworkBasics.ps1

.EXAMPLE
    .\Test-NetworkBasics.ps1 -TestHost intranet.example.com
#>
[CmdletBinding()]
param(
    [string]$PublicIp = '1.1.1.1',
    [string]$TestHost = 'www.microsoft.com'
)

$results = New-Object System.Collections.Generic.List[object]
function Add-Result {
    param([string]$Step, [bool]$Ok, [string]$Detail, [string]$Hint)
    $results.Add([pscustomobject]@{
        Step   = $Step
        Result = $(if ($Ok) { 'PASS' } else { 'FAIL' })
        Detail = $Detail
        Hint   = $(if ($Ok) { '' } else { $Hint })
    })
}

$nics = @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True')
$ipv4 = @($nics | ForEach-Object { $_.IPAddress } | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' })
$validIp = @($ipv4 | Where-Object { $_ -notlike '169.254.*' })
Add-Result '1. IP address' ($validIp.Count -gt 0) ($ipv4 -join ', ') `
    'No valid IP. Check the cable or Wi-Fi, then run: ipconfig /release ; ipconfig /renew'

$gateway = @($nics | ForEach-Object { $_.DefaultIPGateway } | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' }) | Select-Object -First 1
if ($gateway) {
    $gwOk = Test-Connection -ComputerName $gateway -Count 2 -Quiet
    Add-Result '2. Gateway' $gwOk $gateway 'The router does not answer. Check the switch port, cable or access point.'
} else {
    Add-Result '2. Gateway' $false 'none' 'No default gateway. Check DHCP or the static IP settings.'
}

$netOk = Test-Connection -ComputerName $PublicIp -Count 2 -Quiet
Add-Result '3. Internet (IP)' $netOk $PublicIp 'The router answers but the internet does not: check the internet link or the firewall.'

try {
    $dns = Resolve-DnsName -Name $TestHost -Type A -ErrorAction Stop | Where-Object { $_.IPAddress } | Select-Object -First 1
    Add-Result '4. DNS' $true "$TestHost -> $($dns.IPAddress)" ''
} catch {
    Add-Result '4. DNS' $false $TestHost 'Names do not resolve: check the DNS servers, then run: ipconfig /flushdns'
}

$httpsOk = Test-NetConnection -ComputerName $TestHost -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
Add-Result '5. HTTPS' $httpsOk "$($TestHost):443" 'DNS works but HTTPS does not: check the proxy, firewall or antivirus web filter.'

$results | Format-Table -AutoSize -Wrap | Out-String | Write-Output

$firstFail = $results | Where-Object { $_.Result -eq 'FAIL' } | Select-Object -First 1
if ($firstFail) {
    Write-Output "Start here: $($firstFail.Step). $($firstFail.Hint)"
} else {
    Write-Output 'All checks passed. If one site or app still fails, the problem is in that service, not in the network.'
}
