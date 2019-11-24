# openvpn-telegram-notifier
This is a simple perl script which takes some basic informations from the environmet variables provided by the openvpn-server and sends a message with a telegram bot.

It dies with an non-zero exitcode if something is wrong like a missing/invalid config or if the telegram message could not be send. Currently it searches for curl or wget on the system an uses them if possible. 

## Example Config:
    client-connect "/etc/openvpn/telegam_connect_notify.pl connect"
    client-disconnect "/etc/openvpn/telegam_connect_notify.pl disconnect"

The script supports exactly those to options and ignores everything else given from the openvpn-server.

**Optional:**
You can define a list of common names which should be excluded.