# Azure DDNS
Provides an Inadyn compatible DDNS provider which uses an underlying Microsoft Azure DNS Zone to maintain the IP address within a single A record.

The following file will need to be updated on the network device at the location: `/etc/inadyn.conf`
```conf
custom your-ddns.azurewebsites.net:1 {
    hostname    = "your.azuredomain.com"
    username    = "USER"
    password    = ""
    ddns-server = "your-ddns.azurewebsites.net"
    ddns-path   = "/api/ddns/update?%u=%p&hostname=%h&ipaddr=%i"
}
```

__Config Settings:__
- hostname: This MUST be the DNS entry being updated.
- username: This MUST be the query parameter used to authenticate to the Azure Function.
- password: This MUST be the master API key defined for the Azure Function. This value can be found in the App Keys section of the function app configuration.
- ddns-server: This is the location the Azure Function has been deployed.
- ddns-path: DO NOT CHANGE!

__Testing:__
To test this, you will need to have command line access to the device running the `inadyn.service`.
```txt
inadyn -1n --force --loglevel=DEBUG --config=/etc/inadyn.conf
```
