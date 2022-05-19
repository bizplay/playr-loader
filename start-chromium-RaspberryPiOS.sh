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

# Define the browser to use
browser="/usr/bin/chromium-browser"
preferences_file="~/.config/chromium/Default/Preferences"

# Prevent popups or additional empty tabs
sed -i -E 's/("exited_cleanly":\s*)false/\1true/g' $preferences_file
sed -i -E 's/("exit_type":\s*)"Crashed"/\1"Normal"/g' $preferences_file

# Define the command line options for starting browser
# gpu_options="--ignore-gpu-blocklist --enable-experimental-canvas-features --enable-gpu-rasterization --enable-threaded-gpu-rasterization"
gpu_options="--ignore-gpu-blocklist"
persistency_options=""
# --disable-session-crashed-bubble has been deprecated since v57 at the latest
no_nagging_options="--disable-features=SameSiteByDefaultCookies,CookiesWithoutSameSiteMustBeSecure --disable-translate --no-first-run --no-default-browser-check --disable-infobars --autoplay-policy=no-user-gesture-required --no-user-gesture-required --disable-session-crashed-bubble"

# The path to the page that will check internet connection
# before loading the actual signage channel
# NOTE: check the location of the player_loader.html in the following line
execution_path=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
playr_loader_file="${execution_path}/playr_loader.html"

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
# will be processed correctly by the playr_loader html file
channel=$(echo "$channel" | sed 's:%:%25:g;s:?:%3F:g;s:&:%26:g;s:=:%3D:g;s: :%20:g;s_:_%3A_g;s:/:%2F:g;s:;:%3B:g;s:@:%40:g;s:+:%2B:g;s:,:%2C:g;s:#:%23:g')

# Retreiving the device serial number which is specific for Raspberry Pis (other
# devices offer the system-uuid, but that is not available on the Raspberry Pi
# since it uses a different type of BIOS)
system_uuid=$(cat /sys/firmware/devicetree/base/serial-number)

# the --app= option prevents the "Restore pages" popup from showing up after the previous process was killed
$browser ${gpu_options} ${persistency_options} ${no_nagging_options} --kiosk --app="file://"${playr_loader_file}"?channel="${channel}"&watchdog_id="${system_uuid} &

# SIMPLE WATCHDOG FUNCTIONALITY
# Server settings
server_url=${browser_watchdog_server_url:-"http://ajax.playr.biz/watchdogs/$system_uuid/command"}
return_value_restart=${browser_watchdog_return_value_restart:-1}
return_value_no_restart=${browser_watchdog_return_value_no_restart:-0}
server_check_interval=${browser_watchdog_server_check_interval:-300}

# Function that checks a server for a restart signal
# by doing a http GET request to the server_url.
# The result from the get request is stripped of spaces
# and checked for being an integer value and then returned.
# If the result of the request is empty or not an integer value
# return_value_no_restart is returned to minimize the risk of an
# unintended restart of Webconverger
request_restart_signal() {
	local result="$(curl --silent "$server_url")"
	local result_without_spaces=${result// }
	if [[ -z $result_without_spaces ]]; then
		echo $return_value_no_restart
	elif [[ "$result_without_spaces" =~ ^[0-9]+$ ]]; then
		echo $result_without_spaces
	else
		echo $return_value_no_restart
	fi
}
# reboot the computer
reboot_machine() {
	sync
	sudo shutdown --reboot now
}

# Wait to allow the browser to start up properly
# It is best if the browser (playback)
# connects to the backend first before this script does to enable
# the backend to properly initiate the necessary context.
sleep $one_minute

while true; do
	if [ "$(request_restart_signal)" -eq "$return_value_restart" ]; then
		$(reboot_machine)
	fi
	sleep $server_check_interval
done

exit 0