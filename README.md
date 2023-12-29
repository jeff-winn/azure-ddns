# Azure DDNS
Provides an Inadyn compatible DDNS provider hosted by an Azure Function which uses an underlying Microsoft Azure DNS Zone to maintain the IP address for a single A record.

## Deploying the Provider
Within the Microsoft Azure Function portal:
1. Create a new Azure Function
2. Open the Configuration pane, and add a `DnsZoneRGName` application setting. This will need to contain the Resource Group Name for your DNS Zone.
3. Open the Identity pane, and enable a System or User Assigned identity. This identity __MUST__ have `DNS Zone Contributor` role for the DNS Zone the provider will be responsible for modifying.
4. Deploy this codebase into your Azure Function.

## Configuring the Inadyn Client
The following file will need to be updated on the network device at the location: `/etc/inadyn.conf`

```conf
custom your-ddns.azurewebsites.net:1 {
    hostname    = "your.azuredomain.com"
    username    = "code"
    password    = "<<REDACTED>>"
    ddns-server = "your-ddns.azurewebsites.net"
    ddns-path   = "/api/azure-ddns/update?%u=%p&hostname=%h&ipaddr=%i"
}
```

### Configuration Settings
The following describes the aforementioned configuration section settings:

- _hostname_: This __MUST__ be the DNS entry being updated.
- _username_: DO NOT CHANGE!
- _password_: This __MUST__ be an API key defined for the Azure Function. This value can be found in the App Keys section of the Azure Function configuration.
- _ddns-server_: This is the location the Azure Function has been deployed.
- _ddns-path_: DO NOT CHANGE!

## Testing
To test this, you will need to have command line access to the device running the `inadyn.service`.
```txt
inadyn -1n --force --loglevel=DEBUG --config=/etc/inadyn.conf
```

The following snippet depicts what you should see on the Inadyn client when communicating with your DDNS service.
```
GET /api/azure-ddns/update?code=<<YOUR_API_KEY>>&hostname=<<YOUR DOMAIN>>&ipaddr=<<YOUR_IP>> HTTP/1.0
Host: <<AZURE_FUNCTION_URL>>
Authorization: Basic <<REDACTED>>
User-Agent: inadyn/2.9.1 https://github.com/troglobit/inadyn/issues
```
