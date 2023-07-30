#!/usr/bin/env bash

# Remove process and route information when connection closes
rm -rf /var/run/openvpn.pid /config/pia/pia-info/route_info

# Replace resolv.conf with original stored as backup
cat /config/pia/pia-info/resolv_conf_backup > /etc/resolv.conf
