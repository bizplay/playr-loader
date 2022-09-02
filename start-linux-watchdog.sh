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

. ./functions/linux.sh

# Server settings
server_url=${browser_watchdog_server_url:-"http://ajax.playr.biz/watchdogs/$1/command"}
return_value_restart=${browser_watchdog_return_value_restart:-1}
return_value_no_restart=${browser_watchdog_return_value_no_restart:-0}
server_check_interval=${browser_watchdog_server_check_interval:-300}

# Function that checks a server for a restart signal
# by doing a http GET request to the server_url.
# The result from the get request is stripped of spaces
# and checked for being an integer value and then returned.
# If the result of the request is empty or not an integer value
# return_value_no_restart is returned to minimize the risk of an
# unintended restart
request_restart_signal() {
    local result="$(curl --silent "$server_url")"
    local result_without_spaces=${result// /}
    if [[ -z $result_without_spaces ]]; then
        echo $return_value_no_restart
    elif [[ "$result_without_spaces" =~ ^[0-9]+$ ]]; then
        echo $result_without_spaces
    else
        echo $return_value_no_restart
    fi
}

# reboot the computer for linux systems
reboot_machine_linux() {
    sync
    sudo shutdown --reboot now
}

# reboot the computer for osx systems
reboot_machine_osx() {
    sync
    osascript -e 'tell app "System Events" to shut down'
}

# Reboot machine
# Check running OS to decide unix shutdown or OSX shutdown
reboot_machine() {
    if [ "$(uname)" == "Darwin" ]; then
        reboot_machine_osx
    else
        reboot_machine_linux
    fi
}

# Initiate watchdog
start_watchdog() {
    while true; do
        log_info "sending request to $server_url"
        if [ "$(request_restart_signal)" -eq "$return_value_restart" ]; then
            log_warning "received reboot command: restarting machine"
            $(reboot_machine)
        else
            log_info "received command: $? no action yet"
        fi
        sleep $server_check_interval
    done
}

if [[ $1 == "" ]]; then
    log_error "machine_id not passed as argument to wathdog (./startLinuxWatchdog ID)"
    exit 1
fi

log_info "starting watchdog for device $COLOR_GREEN$1"

if ! which curl >/dev/null; then
    log_error "curl not installed on this system, please install curl"
    exit 1
fi

start_watchdog
