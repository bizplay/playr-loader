#!/bin/bash

#
# This file is licensed under the MIT license.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

# Add some terminal colors
COLOR_OFF='\033[0m'       # Text reset
COLOR_RED='\033[0;31m'    # Red
COLOR_YELLOW='\033[0;33m' # Yellow
COLOR_BLUE='\033[0;34m'   # Blue
COLOR_GREEN='\033[0;32m'  # Green

# parse mac address from the ip link command
# ignore loopback devices and focus on link/ether
# extract the mac and select the first one based on activation order in kernel
parse_mac_from_ip_link() {
    echo $(ip link | grep -E "link/ether" | grep -o -E '([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}' | head -1)
}

# get first mac of the network hardware
# order defined by kernel activation order
get_first_hardware_mac() {
    if ! which ip >/dev/null; then
        echo "ip not installed on this system, please install ip"
        exit 1
    fi

    parse_mac_from_ip_link
}

# Use this to write informative log messages to the terminal
log_info() {
    echo -e "[INFO]  - $(date +%F-%T) - $COLOR_BLUE${1}$COLOR_OFF"
}

# Use this to write warning messages to the terminal
log_warning() {
    echo -e "[WARN]  - $(date +%F-%T) - $COLOR_YELLOW${1}$COLOR_OFF"
}

# Use this to write error messages to the terminal
log_error() {
    echo -e "[ERROR] - $(date +%F-%T) - $COLOR_RED${1}$COLOR_OFF"
}
