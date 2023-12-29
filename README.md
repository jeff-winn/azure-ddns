# Azure DDNS
Provides an Inadyn compatible DDNS provider hosted by an Azure Function which uses an underlying Microsoft Azure DNS Zone to maintain the IP address for a single A record.

### Deploying the Provider
Within the Microsoft Azure Function portal:
- Open the Configuration pane, and add a _DnsZoneRGName_ application setting. This will need to contain the DNZ Zone Resource Group within Microsoft Azure for your DNS Zone.
- Open the Identity pane, and enable a System or User Assigned identity. This identity MUST have `DNS Zone Contributor` role for the DNS Zone the provider will be responsible for modifying.

### Configuring the Inadyn Client
The following file will need to be updated on the network device at the location: `/etc/inadyn.conf`

```conf
custom your-ddns.azurewebsites.net:1 {
    hostname    = "your.azuredomain.com"
    username    = "code"
    password    = "<<REDACTED>>"
    ddns-server = "your-ddns.azurewebsites.net"
    ddns-path   = "/api/ddns/update?%u=%p&hostname=%h&ipaddr=%i"
}
```

__Config Settings:__
- hostname: This MUST be the DNS entry being updated.
- username: DO NOT CHANGE!
- password: This MUST be an API key defined for the Azure Function. This value can be found in the App Keys section of the Azure Function configuration.
- ddns-server: This is the location the Azure Function has been deployed.
- ddns-path: DO NOT CHANGE!

__Testing:__
To test this, you will need to have command line access to the device running the `inadyn.service`.
```txt
inadyn -1n --force --loglevel=DEBUG --config=/etc/inadyn.conf
```

The following snippet depicts what you should see on the Inadyn client when communicating with your DDNS service.
```
GET /api/ddns/update?code=<<YOUR_API_KEY>>&hostname=<<YOUR DOMAIN>>&ipaddr=<<YOUR_IP>> HTTP/1.0
Host: <<AZURE_FUNCTION_URL>>
Authorization: Basic <<REDACTED>>
User-Agent: inadyn/2.9.1 https://github.com/troglobit/inadyn/issues
```
