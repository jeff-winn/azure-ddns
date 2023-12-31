# Azure DDNS
Provides an In-a-Dyn compatible DDNS provider that is hosted by an Azure Function which uses an underlying Microsoft Azure hosted DNS Zone to maintain the IP address for a single A record.

## Deploying the Provider
Within the Microsoft Azure Function portal:
1. Create a new Azure Function
2. Open the Configuration pane, and add the following application settings:
    - _AppUsername_ - This is the username that will be required to use the public endpoint.
    - _AppPassword_ - This is the password that will be required to use the public endpoint.
    - _DnsZoneRGName_ - This will need to contain the Resource Group Name for your DNS Zone.
3. Open the Identity pane, and enable a System or User Assigned identity. This identity __MUST__ have `DNS Zone Contributor` role for the DNS Zone the provider will be responsible for modifying.
4. Deploy this codebase into your Azure Function.

## Configuring the In-a-Dyn Client
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

#### Configuration Settings
The following describes the aforementioned configuration section settings:

- _hostname_: This __MUST__ be the FQDN of the DNS entry to update.
- _username_: This __MUST__ match the username used in the _AppUsername_ application configuration setting.
- _password_: This __MUST__ match the password used in the _AppPassword_ application configuration setting.
- _ddns-server_: This is the location where the Azure Function has been deployed.
- _ddns-path_: DO NOT CHANGE!

## Testing
To test this, you will need to have command line access to the device running the `inadyn.service`.
```txt
inadyn -1n --force --loglevel=DEBUG --config=/etc/inadyn.conf
```

The following snippet shows what you should see on the In-a-Dyn client logs when communicating with your DDNS service:
```log
inadyn[527119]: Sending alias table update to DDNS server: GET /nic/update?hostname=your.azuredomain.com&myip=REDACTED HTTP/1.0
inadyn[527119]: Host: your-ddns.azurewebsites.net
inadyn[527119]: Authorization: Basic REDACTED
inadyn[527119]: User-Agent: inadyn/2.9.1 https://github.com/troglobit/inadyn/issues
inadyn[527119]: Successfully sent HTTPS request!
inadyn[527119]: Successfully received HTTPS response (205/8191 bytes)!
inadyn[527119]: DDNS server response: HTTP/1.1 200 OK
Connection: close
Content-Type: text/plain; charset=utf-8
Date: Sun, 31 Dec 2023 02:16:13 GMT

good
inadyn[527119]: Successful alias table update for your.azuredomain.com => new IP# REDACTED
inadyn[527119]: Updating cache for your.azuredomain.com
```
