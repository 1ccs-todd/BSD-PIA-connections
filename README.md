REPO ARCHIVED:  TrueNAS Core is being phased out for Community Edition (Scale).
                These scripts are still viable for FreeBSD host systems.

# Configure PIA VPN Connections

### This is a FreeBSD/TrueNAS CORE Wireguard and OpenVPN fork of https://github.com/glorious1/manual-connections/.
### Which is a FreeBSD OpenVPN fork of the original Linux scripts at https://github.com/pia-foss/manual-connections.  

Fork Notes:
1. The scripts are set up to work via either OpenVPN or Wireguard. 
2. If you clone this repository, the scripts are hardcoded to run from `/config/pia`.  (A TrueNAS standard for permanent jail data.)
3. `run_setup.sh' will prompt and store all needed information.  It calls the following script and so on.  If you're using port forwarding, `port_forwarding.sh` and `refresh_pia_port.sh` are the last scripts called.  The port needs to be refreshed about every 15 minutes.  Cron should look like `*/15 * * * * /config/pia/refresh_pia_port.sh > /config/pia/pia-info/refresh.log 2>&1` and run as `root`.  The output will be in `/config/pia/pia-info/refresh.log`.
4. 'run_setup_again.sh' runs the full setup scripts using the stored data instead of prompting.  Configuration data is stored in /config/pia/pia-info.
5. In `refresh_pia_port.sh`, A command was added to send the port number to the torrent client. Deluge/Transmission are checked for and corresponding command is sent.
6. If you have trouble, carefully read the output to see where it failed.  Should OpenVPN fail to start, `/config/pia/pia-info/debug_info` will print to screen so you can see what was going on with OpenVPN.  The scripts also store a bunch of other stuff in `/config/pia/pia-info`. 
7. At least for OpenVPN, the network interface used is tun0.  During setup, a later script will check for tun0 and offer to kill the openvpn process that started it.  Otherwise, it will create another tun# and report everything is great, but you won't actually have your open port in transmission.
8. FreeBSD service friendly. Both final configured PIA Wireguard and OpenVPN connections can be automated via rc.conf file.
9. Tested on TrueNAS 13.1 jail.  Should operate the same on any FreeBSD 13.x system.

End of Fork Notes

This repository contains documentation on how to create native WireGuard and OpenVPN connections to Private Internet Access' (PIA) __NextGen network__, and also on how to enable Port Forwarding in case you require this feature. You will find a lot of information below. However if you prefer quick test, here is the __TL/DR__:

```
git clone https://github.com/1ccs-todd/manual-connections.git /config/pia
cd /config/pia
./run_setup.sh
```

### Dependencies

In order for the scripts to work, the following packages are installed as needed:
 * `bash`
 * `curl`
 * `jq`
 * (only for WireGuard) `wireguard` kernel module
 * (only for OpenVPN) `openvpn`
 * (only for port forwarding) `base64`

### Disclaimers

 * Port Forwarding is disabled on server-side in the United States.
 * These scripts do not enforce IPv6 or DNS settings, so that you have the freedom to configure your setup the way you desire it to work. This means you should have good understanding of VPN and cybersecurity in order to properly configure your setup. 

## PIA Port Forwarding

The PIA Port Forwarding service (a.k.a. PF) allows you run services on your own devices, and expose them to the internet by using the PIA VPN Network.

This service can be used only AFTER establishing a VPN connection.

## Automated setup of VPN and/or PF

In order to help you use VPN services and PF on any device, we have prepared a few bash scripts that should help you through the process of setting everything up. The scripts also contain a lot of comments, just in case you require detailed information regarding how the technology works. The functionality is controlled via environment variables, so that you have an easy time automating your setup.

Here is a list of scripts you could find useful:
 * [Get the best region and a token](get_region_and_token.sh): This script helps you to get the best region and also to get a token for VPN authentication. Adding your PIA credentials to env vars `PIA_USER` and `PIA_PASS` will allow the script to also get a VPN token. The script can also trigger the WireGuard script to create a connection, if you specify `PIA_AUTOCONNECT=wireguard` or `PIA_AUTOCONNECT=openvpn_udp_standard`
 * [Connect to WireGuard](connect_to_wireguard_with_token.sh): This script allows you to connect to the VPN server via WireGuard.
 * [Connect to OpenVPN](connect_to_openvpn_with_token.sh): This script allows you to connect to the VPN server via OpenVPN.
 * [Enable Port Forwarding](port_forwarding.sh): Enables you to add Port Forwarding to an existing VPN connection. Adding the environment variable `PIA_PF=true` to any of the previous scripts will also trigger this script.

## Manual setup of PF

To use port forwarding on the NextGen network, first of all establish a connection with your favorite protocol. After this, you will need to find the private IP of the gateway you are connected to. In case you are WireGuard, the gateway will be part of the JSON response you get from the server, as you can see in the [bash script](https://github.com/pia-foss/manual-connections/blob/master/wireguard_and_pf.sh#L119). In case you are using OpenVPN, you can find the gateway by checking the routing table with `ip route s t all`.

After connecting and finding out what the gateway is, get your payload and your signature by calling `getSignature` via HTTPS on port 19999. You will have to add your token as a GET var to prove you actually have an active account.

Example:
```bash
bash-5.0# curl -k "https://10.4.128.1:19999/getSignature?token=$TOKEN"
{
    "status": "OK",
    "payload": "eyJ0b2tlbiI6Inh4eHh4eHh4eCIsInBvcnQiOjQ3MDQ3LCJjcmVhdGVkX2F0IjoiMjAyMC0wNC0zMFQyMjozMzo0NC4xMTQzNjk5MDZaIn0=",
    "signature": "a40Tf4OrVECzEpi5kkr1x5vR0DEimjCYJU9QwREDpLM+cdaJMBUcwFoemSuJlxjksncsrvIgRdZc0te4BUL6BA=="
}
```

The payload can be decoded with base64 to see your information:
```bash
$ echo eyJ0b2tlbiI6Inh4eHh4eHh4eCIsInBvcnQiOjQ3MDQ3LCJjcmVhdGVkX2F0IjoiMjAyMC0wNC0zMFQyMjozMzo0NC4xMTQzNjk5MDZaIn0= | base64 -d | jq 
{
  "token": "xxxxxxxxx",
  "port": 47047,
  "expires_at": "2020-06-30T22:33:44.114369906Z"
}
```
This is where you can also see the port you received. Please consider `expires_at` as your request will fail if the token is too old. All ports currently expire after 2 months.

Use the payload and the signature to bind the port on any server you desire. This is also done by curling the gateway of the VPN server you are connected to.
```bash
bash-5.0# curl -sGk --data-urlencode "payload=${payload}" --data-urlencode "signature=${signature}" https://10.4.128.1:19999/bindPort
{
    "status": "OK",
    "message": "port scheduled for add"
}
bash-5.0# 
```

Call __/bindPort__ every 15 minutes, or the port will be deleted!

### Testing your new PF

To test that it works, you can tcpdump on the port you received:

```
bash-5.0# tcpdump -ni any port 47047
```

After that, use curl on the IP of the traffic server and the port specified in the payload which in our case is `47047`:
```bash
$ curl "http://178.162.208.237:47047"
```

and you should see the traffic in your tcpdump:
```
bash-5.0# tcpdump -ni any port 47047
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on any, link-type LINUX_SLL (Linux cooked v1), capture size 262144 bytes
22:44:01.510804 IP 81.180.227.170.33884 > 10.4.143.34.47047: Flags [S], seq 906854496, win 64860, options [mss 1380,sackOK,TS val 2608022390 ecr 0,nop,wscale 7], length 0
22:44:01.510895 IP 10.4.143.34.47047 > 81.180.227.170.33884: Flags [R.], seq 0, ack 906854497, win 0, length 0
```

## License
This project is licensed under the [MIT (Expat) license](https://choosealicense.com/licenses/mit/), which can be found [here](/LICENSE).
