#!/bin/bash

# This batch file is provided to show digital signage content from playr.biz
# To read more on the purpose of this file and how to use it
# see the accompanying README.md file or
# contact your digital signage provider.
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

##########################################################################
#							VARIABLES    								 #
##########################################################################

# Will be filled with the system identifier will be set during execution
# Based on OSX or Linux it will be retrieved differently
system_uuid=""

# Define the browser to use
browser=""
preferences_file="~/.config/chromium/Default/Preferences"

# Define the command line options for starting browser
# gpu_options="--ignore-gpu-blocklist --enable-experimental-canvas-features --enable-gpu-rasterization --enable-threaded-gpu-rasterization"
gpu_options="--ignore-gpu-blocklist"
persistency_options=""
# --disable-session-crashed-bubble has been deprecated since v57 at the latest
no_nagging_options="--disable-features=SameSiteByDefaultCookies,CookiesWithoutSameSiteMustBeSecure --disable-translate --no-first-run --no-default-browser-check --disable-infobars --autoplay-policy=no-user-gesture-required --no-user-gesture-required --disable-session-crashed-bubble"

# The path to the page that will check internet connection
# before loading the actual signage channel
# NOTE: check the location of the player_loader.html in the following line
execution_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
playr_loader_file="${execution_path}/playr_loader.html"

# Add some terminal colors
COLOR_OFF='\033[0m'       # Text reset
COLOR_RED='\033[0;31m'    # Red
COLOR_YELLOW='\033[0;33m' # Yellow
COLOR_BLUE='\033[0;34m'   # Blue
COLOR_GREEN='\033[0;32m'  # Green

##########################################################################
#							   METHODS     								 #
##########################################################################

# Use this to write error messages to the terminal
log_error() {
	echo -e "[ERROR] - $(date +%F-%T) - $COLOR_RED${1}$COLOR_OFF"
}

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

# get system uuid based on ioreg or ip link mac address
get_system_uuid() {
	local result=""

	if [ "$(uname)" == "Darwin" ]; then
		# get platform serial number, parse and strip quotes
		result=$(ioreg -rd1 -c IOPlatformExpertDevice | awk '/IOPlatformSerialNumber/' | grep -o -E '("\w+")$' | sed -E 's/"//g')
	else
		result=$(get_first_hardware_mac)
	fi

	# check return code on error
	if [ "$?" -ne "0" ]; then
		echo "failed to retrieve system_uuid reason: $result"
		exit 1
	else
		echo $result
	fi
}

# return the path for the browser based on operating system
get_chrome_browser() {
	if [ "$(uname)" == "Darwin" ]; then
		echo "Chromium.app"
	else
		echo "/usr/bin/chromium-browser"
	fi
}

##########################################################################
#							   Execution   								 #
##########################################################################

# Fill browser path based on operating system
browser=$(get_chrome_browser)

# Get system ID used in watchdog
# uses ioreg or ip link based on osx or linux environment
system_uuid=$(get_system_uuid)

# Handle failure cause on getting system_uuid
if [ "$?" -ne "0" ]; then
	log_error "$system_uuid"
	exit 1
fi

# The URL that will be played in the browser
if [[ $1 == "" ]]; then
	# Use the generic URL below for ease of use
	# or use the channel url that is shown as
	# 'Playback Address' on your dashboard
	channel="http://play.playr.biz"
else
	channel=$1
fi
# Escape special characters so any parameters of the channel url
# and reload_url will be processed correctly by the player_loader_file
channel=$(echo "$channel" | sed 's:%:%25:g;s:?:%3F:g;s:&:%26:g;s:=:%3D:g;s: :%20:g;s_:_%3A_g;s:/:%2F:g;s:;:%3B:g;s:@:%40:g;s:+:%2B:g;s:,:%2C:g;s:#:%23:g')

# The path to the player-loader.html file that is used to
# check the internet connection and start playback
if [[ $2 == "" ]]; then
	reload_url=file://${playr_loader_file}
else
	reload_url=file://$2
fi

# Only preference file adjustments are needed on Linux
if [ "$(uname)" == "Linux" ]; then
	# Prevent popups or additional empty tabs
	sed -i -E 's/("exited_cleanly":\s*)false/\1true/g' $preferences_file
	sed -i -E 's/("exit_type":\s*)"Crashed"/\1"Normal"/g' $preferences_file
fi

# to check the values of the variables created above uncomment the following line
# echo "file://"${playr_loader_file}"?channel="${channel}"&reload_url="${reload_url}
# the --app= option prevents the "Restore pages" popup from showing up after the previous process was killed
if [ "$(uname)" == "Darwin" ]; then
	open -a "$browser" --args ${gpu_options} ${persistency_options} ${no_nagging_options} --kiosk --app="file://"${playr_loader_file}"?channel="${channel}"&reload_url="${reload_url}"&watchdog_id="${system_uuid}
else
	$browser ${gpu_options} ${persistency_options} ${no_nagging_options} --kiosk --app="file://"${playr_loader_file}"?channel="${channel}"&reload_url="${reload_url}"&watchdog_id="${system_uuid} &
fi

# start watchdog
${execution_path}/start-linux-watchdog.sh $system_uuid
