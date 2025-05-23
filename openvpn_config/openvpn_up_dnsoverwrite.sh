#!/usr/bin/env bash

# Write gateway IP for reference
echo $route_vpn_gateway > /config/pia/pia-info/route_info

# Back up resolv.conf and create new on with PIA DNS
cat /etc/resolv.conf > /config/pia/pia-info/resolv_conf_backup
echo "# Generated by /connect_to_openvpn_with_token.sh" > /etc/resolv.conf
echo "nameserver 10.0.0.241" >> /etc/resolv.conf
