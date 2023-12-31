# Azure DDNS
Provides an Inadyn compatible DDNS provider that is hosted by an Azure Function which uses an underlying Microsoft Azure DNS Zone to maintain the IP address for a single A record.

Keep in mind, this provider is meant to be Inadyn compatible. As such the use of a GET action for an update is not preferred, however that is the standard in use by the client. While a POST action would be my personal preference, compatibility and working is more important.

## Deploying the Provider
Within the Microsoft Azure Function portal:
1. Create a new Azure Function
2. Open the Configuration pane, and add the following application settings:
    - _AppUsername_ - This is the username that will be required to use the public endpoint.
    - _AppPassword_ - This is the password that will be required to use the public endpoint.
    - _DnsZoneRGName_ - This will need to contain the Resource Group Name for your DNS Zone.
3. Open the Identity pane, and enable a System or User Assigned identity. This identity __MUST__ have `DNS Zone Contributor` role for the DNS Zone the provider will be responsible for modifying.
4. Deploy this codebase into your Azure Function.

## Configuring the Inadyn Client
The following file will need to be updated on the network device at the location: `/etc/inadyn.conf`. If you are using a device such as a Unifi Dream Machine or Dream Machine Pro, the file will instead be located at: `/run/ddns_eth{?}_inadyn.conf`.

```conf
custom your-ddns.azurewebsites.net:1 {
    hostname    = "your.azuredomain.com"
    username    = "REDACTED"
    password    = "REDACTED"
    ddns-server = "your-ddns.azurewebsites.net"
    ddns-path   = "/nic/update?hostname=%h&myip=%i"
}
```

### Configuration Settings
The following describes the aforementioned configuration section settings:

- _hostname_: This __MUST__ be the FQDN of the DNS entry being updated.
- _username_: This __MUST__ match the username you set in the _AppUsername_ application configuration setting.
- _password_: This __MUST__ match the password you set in the _AppPassword_ application configuration setting.
- _ddns-server_: This is the location the Azure Function has been deployed.
- _ddns-path_: DO NOT CHANGE!

## Testing
To test this, you will need to have command line access to the device running the `inadyn.service`.
```txt
inadyn -1n --force --loglevel=DEBUG --config=/etc/inadyn.conf
```

The following snippet depicts what you should see on the Inadyn client when communicating with your DDNS service.
```
GET /nic/update?&hostname=<<YOUR_DOMAIN>>&myip=<<YOUR_IP>> HTTP/1.0
Host: <<AZURE_FUNCTION_URL>>
Authorization: Basic <<YOUR_CREDENTIALS>>
User-Agent: inadyn/2.9.1 https://github.com/troglobit/inadyn/issues
```
