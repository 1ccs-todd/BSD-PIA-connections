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

# All necessary variables for remaining scripts.

echo "
################################
    run_setup_again.sh
################################

"
# Collect cached data.
# run setup scripts as usual.

# Only allow script to run as root

if [ "$(whoami)" != "root" ]; then
  echo "This script needs to be run as root. Try again with 'sudo $0'"
  exit 1
fi

# Fetching PIA credentials from local cached data.
# Username on first line, password on second
declare -a creds # an array
readarray -t creds < /config/pia/pia-info/pia_creds.txt
PIA_USER="${creds[0]}"
PIA_PASS="${creds[1]}"
echo "Retrieved credentials"
export PIA_USER
export PIA_PASS

# Retreiving variables.
pf_filepath=/config/pia/pia-info

PIA_PF="$( cat $pf_filepath/PIA_PF )"
export PIA_PF

PIA_DNS="$( cat $pf_filepath/PIA_DNS )"
export PIA_DNS

PIA_AUTOCONNECT="$( cat $pf_filepath/PIA_AUTOCONNECT )"
export PIA_AUTOCONNECT

MAX_LATENCY="$( cat $pf_filepath/MAX_LATENCY )"
export MAX_LATENCY


./get_region_and_token.sh
