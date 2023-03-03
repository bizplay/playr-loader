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

# Update the system since that will prevent the "updates available"
# overlay when the Pi starts up. Since all updates that were available
# for the Pi in the last couple of years have been installed without
# any problems, it is assumed safe to do this.
# sudo apt update
# sudo apt upgrade -y
# sudo apt full-upgrade -y
# sudo apt autoremove -y

# Add some terminal colors
COLOR_OFF='\033[0m'       # Text reset
COLOR_RED='\033[0;31m'    # Red
COLOR_YELLOW='\033[0;33m' # Yellow
COLOR_BLUE='\033[0;34m'   # Blue
COLOR_GREEN='\033[0;32m'  # Green

# path used to determine other script/html locations
execution_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# The path to the page that will check internet connection
# before loading the actual signage channel
# NOTE: check the location of the player_loader.html in the following line
playr_loader_file="${execution_path}/playr_loader.html"

##########################################################################
#							   METHODS     								 #
##########################################################################

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

# get system uuid based on ioreg or ip link mac address or rpi serial number
get_system_uuid() {
    local result=""

    if [ "$(uname)" == "Darwin" ]; then
        # get platform serial number, parse and strip quotes
        result=$(ioreg -rd1 -c IOPlatformExpertDevice | awk '/IOPlatformSerialNumber/' | grep -o -E '("\w+")$' | sed -E 's/"//g')
    elif cat /proc/cpuinfo | grep "Raspberry Pi" &>/dev/null; then
        result=$(cat /sys/firmware/devicetree/base/serial-number)
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

# Get installed browser detected on a linux system using executable detection in PATH
get_installed_browser_linux() {
    # List of supported browsers
    supported_browsers=("google-chrome" "chromium-browser" "firefox")

    # Iterate through the list of browsers
    for browser in "${supported_browsers[@]}"; do
        # Check if the browser is installed
        found_browser_path=$(which $browser)
        if [ -n "$found_browser_path" ]; then
            found_browser=$browser
            break
        fi
    done

    if [ -z "$found_browser" ]; then
        echo "Error: No supported browser (${supported_browsers[@]}) found."
    else
        echo $found_browser "|" $found_browser_path
    fi
}

# Get installed browser on OSX by detecting if the app is installed
get_installed_browser_mac() {
    # List of supported browsers
    supported_browsers=("Google Chrome.app" "Firefox.app")

    # Iterate through the list of browsers
    for browser in "${supported_browsers[@]}"; do
        # Check if the browser is installed
        if find /Applications -maxdepth 1 -name "$browser" | grep -q .; then
            # change spaces to a _ and make it lower case
            found_browser=$(echo $browser | tr '[:upper:]' '[:lower:]' | tr '-' '_')
            found_browser_path=$(find /Applications -maxdepth 1 -name "${browser}")
            break
        fi
    done

    if [ -z "$found_browser" ]; then
        echo "Error: No supported browser (${supported_browsers[@]}) found."
    else
        echo $found_browser "|" $found_browser_path
    fi
}

get_installed_browser() {
    if [ "$(uname)" == "Darwin" ]; then
        get_installed_browser_mac
    else
        get_installed_browser_linux
    fi
}

# update your browser preferences to fix unwanted popup messages
update_browser_preferences() {
    # Variables for the location of preference files
    google_chrome_darwin_pref_file="$HOME/Library/Application Support/Google/Chrome/Default/Preferences"
    google_chrome_linux_pref_file="$HOME/.config/google-chrome/Default/Preferences"

    chromium_browser_darwin_pref_file="$HOME/Library/Application Support/Chromium/Default/Preferences"
    chromium_browser_linux_pref_file="$HOME/.config/chromium/Default/Preferences"

    firefox_darwin_pref_file="$HOME/Library/Application Support/Firefox/Profiles/*.default/prefs.js"
    firefox_linux_pref_file="$HOME/.mozilla/firefox/*.default/prefs.js"

    # Lower case the browser name for a valid variable name
    # Replacing all '-' with '_' in the browser name for a valid variable name
    browser="$(echo $1 | tr '[:upper:]' '[:lower:]' | tr '-' '_')"

    os=$(uname)
    # Lower case the uname output for valid variable name
    os="$(echo $os | tr '[:upper:]' '[:lower:]')"

    # Use eval to dynamically select the pref file variable
    pref_file_var="${browser}_${os}_pref_file"
    pref_file=$(eval echo \$${pref_file_var})

    if [ -f "$pref_file" ]; then
        # Update the preference file to set 'exited_cleanly' to true and 'exit_type' to 'normal'
        sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' "$pref_file" || true
        sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' "$pref_file" || true
        echo "Successfully updated preferences for $browser"
    else
        echo "Error: Could not find preference file at $pref_file for $browser"
    fi
}

get_playr_channel() {
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
    echo "$channel" | sed 's:%:%25:g;s:?:%3F:g;s:&:%26:g;s:=:%3D:g;s: :%20:g;s_:_%3A_g;s:/:%2F:g;s:;:%3B:g;s:@:%40:g;s:+:%2B:g;s:,:%2C:g;s:#:%23:g'
}

get_reload_url() {
    # The path to the player-loader.html file that is used to
    # check the internet connection and start playback
    if [[ $1 == "" ]]; then
        reload_url=file://${playr_loader_file}
    else
        reload_url=file://$1
    fi
    echo $reload_url
}

open_playr() {
    browser=$1
    channel=$2
    uuid=$3
    reload_url=$4

    # Define the command line options for starting browser
    # gpu_options="--ignore-gpu-blocklist --enable-experimental-canvas-features --enable-gpu-rasterization --enable-threaded-gpu-rasterization"
    gpu_options="--ignore-gpu-blocklist"
    persistency_options=""
    # --disable-session-crashed-bubble has been deprecated since v57 at the latest
    no_nagging_options="--simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT' --disable-features=SameSiteByDefaultCookies,CookiesWithoutSameSiteMustBeSecure --disable-translate --no-first-run --no-default-browser-check --disable-infobars --autoplay-policy=no-user-gesture-required --no-user-gesture-required --disable-session-crashed-bubble"

    
    browser_startup="${gpu_options} ${persistency_options} ${no_nagging_options} --kiosk --app=file://${playr_loader_file}?channel=${channel}&reload_url=${reload_url}&watchdog_id=${uuid}&playr_id=${uuid}"
    log_info "this is the startup :: $browser_startup"

    # overwrite startup if it's a firefox browser
    lowercase_path=$(echo "$browser" | tr '[:upper:]' '[:lower:]')
    if [[ "${lowercase_path}" =~ .*firefox.* ]]; then
        browser_startup="--kiosk file://${playr_loader_file}?channel=${channel}&reload_url=${reload_url}&watchdog_id=${uuid}&playr_id=${uuid}"
    fi

    if [ "$(uname)" == "Darwin" ]; then
        open -a "$browser" --args $browser_startup
    else
        $browser $browser_startup &
    fi
}

# Get installed browser name and path
result=$(get_installed_browser)
if [[ $result == Error* ]]; then
    log_error "${result}"
    exit 1
else
    log_info "Found browser: $result"
fi

# result is filled with "browsername|browserpath" use read to split '|' and parse into array
IFS='|' read -ra arr <<<"$result"
found_browser=${arr[0]}
found_browser_path=$(echo ${arr[1]} | sed -e 's/^[[:space:]]*//')

# Update the preferences of the found browser
output=$(update_browser_preferences ${found_browser})
if [[ $output == Error* ]]; then
    log_warning "${output}"
else
    log_info "${output}"
fi

channel=$(get_playr_channel $1)
system_uuid=$(get_system_uuid)
reload_url=$(get_reload_url $2)

# open the playr browser pointing to the correct path
open_playr "${found_browser_path}" "${channel}" "${system_uuid}" "${reload_url}"

# # start the watchdog
${execution_path}/start-watchdog.sh $system_uuid
