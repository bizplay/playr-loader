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
# The default path to the log file
log_file_name=${start_playr_log_file_name:-"/var/log/start_playr.log"}

# Use this to write informative log messages to the log file
log_to_file() {
  echo -e "$(date +%F-%T) - ${1}" >> $log_file_name
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

# Determine a writable location for the log file.
# Preference order:
#   1. the configured/default location (start_playr_log_file_name, default /var/log/...)
#   2. ~/log/<logfile>  (directory created if needed) when the first is not writable
#   3. /tmp/<logfile>   (last resort so logging keeps working)
# Sets the global log_file_name and records whether it had to fall back.
log_file_fallback_reason=""
resolve_log_file() {
  # touch succeeds when the file is writable or can be created in its directory,
  # so it doubles as a "can we write here?" test for the target location.
  if touch "$log_file_name" 2>/dev/null; then
    return 0
  fi
  log_file_fallback_reason="cannot write to $log_file_name"

  local log_base
  log_base=$(basename "$log_file_name")

  local fallback_dir="$HOME/log"
  local fallback_file="$fallback_dir/$log_base"
  if mkdir -p "$fallback_dir" 2>/dev/null && touch "$fallback_file" 2>/dev/null; then
    log_file_name="$fallback_file"
    return 0
  fi

  # Last resort so logging keeps working
  local tmp_file="/tmp/$log_base"
  if touch "$tmp_file" 2>/dev/null; then
    log_file_name="$tmp_file"
    return 0
  fi

  return 1
}

# Keep the log from growing without bound: once it passes 1 MB, delete it and
# start a fresh file instead of appending forever. Uses wc -c for portability
# (stat's size flags differ between Linux/busybox and macOS/BSD).
rotate_log_if_needed() {
  local max_size=1048576 # 1 MB
  if [[ -f "$log_file_name" ]]; then
    local size
    size=$(wc -c < "$log_file_name" 2>/dev/null | tr -d '[:space:]')
    if [[ -n "$size" ]] && [[ "$size" -gt "$max_size" ]]; then
      rm -f "$log_file_name"
    fi
  fi
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
  supported_browsers=("google-chrome" "chromium-browser" "chromium" "firefox")

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
  chromium_linux_pref_file="$HOME/.config/chromium/Default/Preferences"

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

# Current output resolution as WIDTHxHEIGHT (Wayland/DRM first, xrandr as fallback)
get_primary_resolution() {
  local mode=""
  local mode_file

  if command -v wlr-randr >/dev/null 2>&1; then
    mode=$(wlr-randr 2>/dev/null | awk '/current/ {print $1; exit}')
  fi

  if [ -z "$mode" ]; then
    for mode_file in /sys/class/drm/card*-HDMI-A-1/modes /sys/class/drm/card*-HDMI-A-2/modes /sys/class/drm/card*-*/modes; do
      if [ -r "$mode_file" ]; then
        mode=$(head -n1 "$mode_file")
        if [ -n "$mode" ]; then
          break
        fi
      fi
    done
  fi

  if [ -z "$mode" ] && command -v xrandr >/dev/null 2>&1; then
    mode=$(xrandr -q 2>/dev/null | awk '/\*/ {print $1; exit}')
  fi

  echo "$mode"
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

  log_to_file "using browser    :: $browser"
  log_to_file "using channel    :: $channel"
  log_to_file "using uuid       :: $uuid"
  log_to_file "using reload_url :: $reload_url"
  # Define the command line options for starting browser
  # gpu_options="--ignore-gpu-blocklist --enable-experimental-canvas-features --enable-gpu-rasterization --enable-threaded-gpu-rasterization"
  if [ "$(uname -m)" == "aarch64" ]; then
    gpu_options=""
  else
    gpu_options="--ignore-gpu-blocklist"
  fi
  persistency_options=""
  # --disable-session-crashed-bubble has been deprecated since v57 at the latest
  if [ "$(uname -m)" == "aarch64" ]; then
    # to prevent new keyring dialog on Raspberry PiOS: --password-store=basic --disable-features=DbusSecretPortal  
    no_nagging_options="--simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT' --disable-features=SameSiteByDefaultCookies,CookiesWithoutSameSiteMustBeSecure --disable-translate --no-first-run --disable-first-run-ui --no-default-browser-check --autoplay-policy=no-user-gesture-required --no-user-gesture-required --disable-search-engine-choice-screen --use-fake-device-for-media-stream --auto-accept-camera-and-microphone-capture --password-store=basic --disable-features=DbusSecretPortal"
  else
    no_nagging_options="--simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT' --disable-features=SameSiteByDefaultCookies,CookiesWithoutSameSiteMustBeSecure --disable-translate --no-first-run --disable-first-run-ui --no-default-browser-check --autoplay-policy=no-user-gesture-required --no-user-gesture-required --disable-search-engine-choice-screen --use-fake-device-for-media-stream --auto-accept-camera-and-microphone-capture"
  fi
  wayland_options=""
  if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    log_to_file "Wayland detected"
    wayland_options="--ozone-platform=wayland"
  fi
  # On Raspberry Pi use a scaling factor of 2 when the screen resolution is set to 4K
  # (assuming 4K is identified by a horizontal or vertical resolution greater than 1920)
  scaling_options=""
  if [ "$(uname -m)" == "aarch64" ]; then
    resolution=$(get_primary_resolution)
    horizontal=$(echo "$resolution" | cut -d'x' -f 1)
    vertical=$(echo "$resolution" | cut -d'x' -f 2)
    if [[ "$horizontal" =~ ^[0-9]+$ && "$vertical" =~ ^[0-9]+$ ]]; then
      if [ "$horizontal" -gt "$vertical" ]; then
        if [ "$horizontal" -gt "1920" ]; then
          scaling_options="--force-device-scale-factor=2"
          log_to_file "4K detected, setting scaling options to 2"
        fi
      else
        if [ "$vertical" -gt "1920" ]; then
          scaling_options="--force-device-scale-factor=2"
          log_to_file "4K detected, setting scaling options to 2"
        fi
      fi
    else
      log_to_file "resolution is not a number"
    fi
  fi

  browser_startup="${gpu_options} ${persistency_options} ${no_nagging_options} ${scaling_options} ${wayland_options} --kiosk --app=file://${playr_loader_file}?channel=${channel}&reload_url=${reload_url}&watchdog_id=${uuid}&player_id=${uuid}"
  log_info "this is the startup :: $browser_startup"
  log_to_file "this is the startup :: $browser_startup"

  # overwrite startup if it's a firefox browser
  lowercase_path=$(echo "$browser" | tr '[:upper:]' '[:lower:]')
  if [[ "${lowercase_path}" =~ .*firefox.* ]]; then
    browser_startup="--kiosk file://${playr_loader_file}?channel=${channel}&reload_url=${reload_url}&watchdog_id=${uuid}&player_id=${uuid}"
    log_warning "this is the FF startup :: $browser_startup"
    log_to_file "this is the FF startup :: $browser_startup"
  fi

  if [ "$(uname)" == "Darwin" ]; then
    open -a "$browser" --args $browser_startup
  else
    $browser $browser_startup &
  fi
}

# Pick a writable log location (falls back from /var/log to ~/log to /tmp) and
# rotate the log up front so a large file from a previous run is not kept.
resolve_log_file
rotate_log_if_needed
log_info "logging to $log_file_name"
if [[ -n $log_file_fallback_reason ]]; then
  log_warning "using fallback log location ($log_file_fallback_reason)"
fi

# Get installed browser name and path
result=$(get_installed_browser)
if [[ $result == Error* ]]; then
  log_error "${result}"
  log_to_file "error: ${result}"
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
  log_to_file "warning: ${output}"
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
log_info "started watchdog"
log_to_file "started watchdog"
exit 0
