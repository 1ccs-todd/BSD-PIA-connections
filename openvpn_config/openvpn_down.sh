#!/usr/bin/env bash

# Remove process and route information when connection closes
rm -rf /var/run/openvpn.pid /config/pia/pia-info/route_info
