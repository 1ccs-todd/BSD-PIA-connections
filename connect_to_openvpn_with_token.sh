#!/usr/local/bin/bash
# Copyright (C) 2020 Private Internet Access, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

echo "
#######################################
   connect_to_openvpn_with_token.sh
#######################################
"

# This function allows you to check if the required tools have been installed.
function check_tool() {
  cmd=$1
  package=$2
  if ! command -v $cmd &>/dev/null
  then
    echo "$cmd could not be found"
    echo "Installing $package"
    pkg install -y $package
  fi
}
# Now we call the function to make sure we can use openvpn, curl and jq.
check_tool openvpn openvpn
check_tool curl curl
check_tool jq jq

# Check if manual PIA OpenVPN connection is already initialized.
# Multi-hop is out of the scope of this repo, but you should be able to
# get multi-hop running with both OpenVPN and WireGuard.
pid_filepath="/var/run/openvpn.pid"
if ifconfig tun0; then
  echo The tun0 adapter already exists, that interface is required
  echo for this configuration.
  if [ -f "$pid_filepath" ]; then
    old_pid="$( cat "$pid_filepath" )"
    old_pid_name="$( ps -p "$old_pid" -o comm= )"
    if [[ $old_pid_name == 'openvpn' ]]; then
      echo
      echo It seems likely that process $old_pid is an OpenVPN connection
      echo that was established by using this script. Unless it is closed
      echo you would not be able to get a new connection.
      echo -n "Do you want to run $ kill $old_pid (Y/n): "
      read close_connection
    fi
    if echo ${close_connection:0:1} | grep -iq n ; then
      echo Closing script. Resolve tun0 adapter conflict and run the script again.
      exit 1
    fi
    echo Killing the existing OpenVPN process and waiting 5 seconds...
    kill $old_pid
    sleep 5
  fi
fi

# PIA currently does not support IPv6. In order to be sure your VPN
# connection does not leak, it is best to disabled IPv6 altogether.
<< 'MULTILINE-COMMENT'
( This doesn't work on FreeBSD. IPv6 is instead disabled in 
openvpn_config/standard.ovpn and strong.ovpn )
if [ $(sysctl -n net.ipv6.conf.all.disable_ipv6) -ne 1 ] ||
  [ $(sysctl -n net.ipv6.conf.default.disable_ipv6) -ne 1 ]
then
  echo 'You should consider disabling IPv6 by running:'
  echo 'sysctl -w net.ipv6.conf.all.disable_ipv6=1'
  echo 'sysctl -w net.ipv6.conf.default.disable_ipv6=1'
fi
MULTILINE-COMMENT

#  Check if the mandatory environment variables are set.
if [[ ! $OVPN_SERVER_IP ||
  ! $OVPN_HOSTNAME ||
  ! $PIA_TOKEN ||
  ! $CONNECTION_SETTINGS ]]; then
  echo 'This script requires 4 env vars:'
  echo 'PIA_TOKEN           - the token used for authentication'
  echo 'OVPN_SERVER_IP      - IP that you want to connect to'
  echo 'OVPN_HOSTNAME       - name of the server, required for ssl'
  echo 'CONNECTION_SETTINGS - the protocol and encryption specification'
  echo '                    - available options for CONNECTION_SETTINGS are:'
  echo '                        * openvpn_udp_standard'
  echo '                        * openvpn_udp_strong'
  echo '                        * openvpn_tcp_standard'
  echo '                        * openvpn_tcp_strong'
  echo
  echo You can also specify optional env vars:
  echo "PIA_PF                - enable port forwarding"
  echo "PAYLOAD_AND_SIGNATURE - In case you already have a port."
  echo
  echo An easy solution is to just run get_region_and_token.sh
  echo as it will guide you through getting the best server and
  echo also a token. Detailed information can be found here:
  echo https://github.com/pia-foss/manual-connections
  exit 1
fi

# Create a credentials file with the login token
echo "Trying to write /config/pia/pia-info/pia.ovpn...
"
echo "Removing old credentials and route_info from /config/pia/pia-info/"
rm -f /config/pia/pia-info/credentials /config/pia/pia-info/route_info
echo ${PIA_TOKEN:0:62}"
"${PIA_TOKEN:62} > /config/pia/pia-info/credentials || exit 1
chmod 600 /config/pia/pia-info/credentials

# Translate connection settings variable
IFS='_'
read -ra connection_settings <<< "$CONNECTION_SETTINGS"
IFS=' '
protocol=${connection_settings[1]}
encryption=${connection_settings[2]}

prefix_filepath="openvpn_config/standard.ovpn"
if [[ $encryption == "strong" ]]; then
  prefix_filepath="openvpn_config/strong.ovpn"
fi

if [[ $protocol == "udp" ]]; then
  if [[ $encryption == "standard" ]]; then
    port=1198
  else
    port=1197
  fi
else
  if [[ $encryption == "standard" ]]; then
    port=502
  else
    port=501
  fi
fi

# Create the OpenVPN config based on the settings specified
cat $prefix_filepath > /config/pia/pia-info/pia.ovpn || exit 1
echo remote $OVPN_SERVER_IP $port $protocol >> /config/pia/pia-info/pia.ovpn

# Copy the up/down scripts to /config/pia/pia-info/
# based upon use of PIA DNS
if [ "$PIA_DNS" != true ]; then
  cp openvpn_config/openvpn_up.sh /config/pia/pia-info/
  cp openvpn_config/openvpn_down.sh /config/pia/pia-info/
  echo This configuration will not use PIA DNS.
  echo If you want to also enable PIA DNS, please start the script
  echo with the env var PIA_DNS=true. Example:
  echo $ OVPN_SERVER_IP=\"$OVPN_SERVER_IP\" OVPN_HOSTNAME=\"$OVPN_HOSTNAME\" \
    PIA_TOKEN=\"$PIA_TOKEN\" CONNECTION_SETTINGS=\"$CONNECTION_SETTINGS\" \
    PIA_PF=true PIA_DNS=true ./connect_to_openvpn_with_token.sh
else
  cp openvpn_config/openvpn_up_dnsoverwrite.sh /config/pia/pia-info/openvpn_up.sh
  cp openvpn_config/openvpn_down_dnsoverwrite.sh /config/pia/pia-info/openvpn_down.sh
fi

# Start the OpenVPN interface.
# If something failed, stop this script.
# If you get DNS errors because you miss some packages,
# just hardcode /etc/resolv.conf to "nameserver 10.0.0.242".
#rm -f /config/pia/pia-info/debug_info
echo "
Trying to start the OpenVPN connection..."
/usr/local/sbin/openvpn --daemon \
  --config "/config/pia/pia-info/pia.ovpn" \
  --log "/config/pia/pia-info/debug_info" || exit 1

echo "
The OpenVPN connect command was issued.

Confirming OpenVPN connection state... "

# Check if manual PIA OpenVPN connection is initialized.
# Manually adjust the connection_wait_time if needed
connection_wait_time=10
confirmation="Initialization Sequence Complete"
for (( timeout=0; timeout <=$connection_wait_time; timeout++ ))
do
  sleep 1
  if grep -q "$confirmation" /config/pia/pia-info/debug_info; then
    connected=true
    break
  fi
done

ovpn_pid="$( cat /var/run/openvpn.pid )"
echo "Reading gateway_ip from /config/pia/pia-info/route_info"
gateway_ip="$( cat /config/pia/pia-info/route_info )"

# Report and exit if connection was not initialized within 10 seconds.
if [ "$connected" != true ]; then
  echo "The VPN connection was not established within 10 seconds."
  kill $ovpn_pid
  echo \n"Openvpn debug info at /config/pia/pia-info/debug_info:"
  cat  /config/pia/pia-info/debug_info
  exit 1
fi

echo "Initialization Sequence Complete!

At this point, internet should work via VPN.
"

echo "OpenVPN Process ID: $ovpn_pid
VPN route IP: $gateway_ip

To disconnect the VPN, run:

--> sudo kill $ovpn_pid <--
"

# This section will stop the script if PIA_PF is not set to "true".
if [ "$PIA_PF" != true ]; then
  echo
  echo If you want to also enable port forwarding, please start the script
  echo with the env var PIA_PF=true. Example:
  echo $ OVPN_SERVER_IP=\"$OVPN_SERVER_IP\" OVPN_HOSTNAME=\"$OVPN_HOSTNAME\" \
    PIA_TOKEN=\"$PIA_TOKEN\" CONNECTION_SETTINGS=\"$CONNECTION_SETTINGS\" \
    PIA_PF=true ./connect_to_openvpn_with_token.sh
  exit
fi

echo "
This script got started with PIA_PF=true.
Starting procedure to enable port forwarding by running the following command:
$ PIA_TOKEN=\"$PIA_TOKEN\" \\
  PF_GATEWAY=\"$gateway_ip\" \\
  PF_HOSTNAME=\"$OVPN_HOSTNAME\" \\
  ./port_forwarding.sh
"

PIA_TOKEN=$PIA_TOKEN \
  PF_GATEWAY="$gateway_ip" \
  export PF_GATEWAY
  PF_HOSTNAME="$OVPN_HOSTNAME" \
  export PF_HOSTNAME
  ./port_forwarding.sh


# Save variables to files so refresh script can get them
pf_filepath=/config/pia/pia-info
echo "$PF_HOSTNAME" > $pf_filepath/PF_HOSTNAME
echo "$gateway_ip" > $pf_filepath/PF_GATEWAY
