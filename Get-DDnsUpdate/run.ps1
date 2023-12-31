using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

if ($env:IsDebugEnabled) {
    Wait-Debugger
}

$authHeader = $Request.Headers.Authorization
if(-not $authHeader -or -not $authHeader.startsWith("Basic ")) {
    Write-Error "The Basic authorization header was not provided in the request."

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::Unauthorized
    })

    exit
}

# Decode the username and password from the authorization header.
$auth = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($authHeader.substring(6))).split(':')
$username = $auth[0]
$password = $auth[1]

Write-Debug "Authorization: $username / ********"

if (-not $env:AppUsername -or -not $env:AppPassword) {
    Write-Error "No credentials have been set, please ensure the username and password are set within the application settings."

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::InternalServerError
    })

    exit
} elseif ($username -ne $env:AppUsername -or $password -ne $env:AppPassword) {
    Write-Error "The credentials did not match those configured in the application settings. Please check your configuration and try again."

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::Unauthorized
    })

    exit
}

$dnsZoneRGName = $env:DnsZoneRGName
if (-not $dnsZoneRGName) {
    Write-Error "The Resource Group name has not been specified. Please ensure the DnsZoneRGName application setting has been configured."

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::InternalServerError
    })

    exit
}

$hostname = $Request.Query.HostName
if (-not $hostname) {
    Write-Error "The hostname was not provided in the request."

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body = "nohost"
    })

    exit
}

Write-Debug "Hostname: $hostname"

$ipAddr = $Request.Query.MyIP
if (-not $ipAddr) {
    Write-Error "The IP address was not provided in the request."

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::BadRequest
    })

    exit
}

Write-Debug "New IP Address: $ipAddr"

$count = [regex]::matches($hostname, '[\.]').count
Write-Debug "Found $count periods (.) within hostname '$hostname' provided."

# Determines whether a TLD has been provided using the number of periods included in the hostname.
if ($count -eq 1) {
    $dnsName = "@"
    $zoneName = $hostname
} else {
    $dnsName = $hostname.Substring(0, $hostname.IndexOf('.'))
    $zoneName = $hostname.Substring($hostname.IndexOf('.') + 1)
}

Write-Debug "Name: $dnsName"
Write-Debug "DNS Zone: $zoneName"
Write-Debug "Resource Group: $dnsZoneRGName"

$rs = Get-AzDnsRecordSet -ResourceGroupName $dnsZoneRGName -ZoneName $zoneName -Name $dnsName -RecordType A
if (-not $rs) {
    Write-Error "Could not locate the DNS record '$dnsName' in zone '$zoneName'. Please check your Azure DNS configuration and try again."

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body = "nofqdn"
    })

    exit
} elseif ($rs.TargetResourceId) {
    # The recordset being used is an alias to another recordset, rather than the owner. Abort.
    Write-Error "Could not update the DNS record '$dnsName' in zone '$zoneName' because it is an alias. Please check your Azure DNS configuration and try again."

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body = "nofqdn"
    })

    exit
}

Write-Debug "Checking the existing records for zone '$zoneName'..."

$found = $false
$ipAddrsToRemove = @()

foreach ($record in $rs.Records) {
    if ($record.Ipv4Address -ne $ipAddr) {
        Write-Debug "Found IP address $record.Ipv4Address which does not belong in the record set..."
        $ipAddrsToRemove += $record.Ipv4Address
    } else {
        Write-Debug "Expected IP address already exists within the record set..."
        $found = $true
    }
}

Write-Information "Preparing to update the DNS zone '$zoneName' in Resource Group '$dnsZoneRGName'..."
$saveChanges = $false

if ($ipAddrsToRemove.count -gt 0) {
    Write-Debug "Removing unnecessary IPv4 addresses..."

    foreach ($existingIpAddr in $ipAddrsToRemove) {
        Remove-AzDnsRecordConfig -RecordSet $rs -Ipv4Address $existingIpAddr
        Write-Information "Removed IPv4 address '$existingIpAddr' from DNS zone: '$zoneName'."
    }

    $saveChanges = $true
}

if (!$found) {
    Add-AzDnsRecordConfig -RecordSet $rs -Ipv4Address $ipAddr
    Write-Information "Added new IPv4 Address '$ipAddr' to DNS zone '$zoneName'."

    $saveChanges = $true
}

if ($saveChanges) {
    Set-AzDnsRecordSet -RecordSet $rs
    Write-Information "Successfully updated DNS zone '$zoneName' in Resource Group '$dnsZoneRGName'."
    
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = "good"
    })

    exit
} else {
    Write-Information "No change required for DNS zone '$zoneName' in Resource Group '$dnsZoneRGName'."

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = "nochg"
    })

    exit
}