using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$dnsZoneRGName = $env:DnsZoneRGName
if (-not $dnsZoneRGName) {
    Write-Error "The DNS Zone Resource Group name has not been specified. Please ensure the DnsZoneRGName environment variable has been set."

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::BadRequest
    })

    exit
}

$hostname = $Request.Query.HostName
if (-not $hostname) {
    Write-Error "The host name was not provided in the request."

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::BadRequest
    })

    exit
}

$ipAddr = $Request.Query.IPAddr
if (-not $ipAddr) {
    Write-Error "The new IPAddr was not provided in the request."

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::BadRequest
    })

    exit
}

$dnsName = $hostname.Substring(0, $hostname.IndexOf('.'))
$zoneName = $hostname.Substring($hostname.IndexOf('.') + 1)

$rs = Get-AzDnsRecordSet -ResourceGroupName $dnsZoneRGName -ZoneName $zoneName -Name $dnsName -RecordType A
if (-not $rs) {
    Write-Error "Could not locate the DNS record $dnsName in zone $zoneName. Please check your Azure configuration and try again."

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::BadRequest
    })

    exit
}

Write-Host "Checking the existing records for zone $zoneName..."

$found = $false
$ipAddrsToRemove = @()

foreach ($record in $rs.Records) {
    if ($record.Ipv4Address -ne $ipAddr) {
        # The address was not correct, add it into the array of items to remove.
        $ipAddrsToRemove += $record.Ipv4Address
    } else {
        # The address already exists, do not try to add it later.
        Write-Host "Address already exists within the recordset..."
        $found = $true
    }
}

Write-Information "Preparing to update the DNS zone '$zoneName' in resource group '$dnsZoneRGName'..."

foreach ($existingIpAddr in $ipAddrsToRemove) {
    Remove-AzDnsRecordConfig -RecordSet $rs -Ipv4Address $existingIpAddr
    Write-Information "Removed IPv4 address '$existingIpAddr' from DNS zone: '$zoneName'."
}

if (!$found) {
    Add-AzDnsRecordConfig -RecordSet $rs -Ipv4Address $ipAddr
    Write-Information "Added new IPv4 Address '$ipAddr' to DNZ zone '$zoneName'."
}

Set-AzDnsRecordSet -RecordSet $rs
Write-Information "Successfully updated DNS zone '$zoneName'."

# The response values returned here are required by the Inadyn client, do not change!
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body       = "good"
})