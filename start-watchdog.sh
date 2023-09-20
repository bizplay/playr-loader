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
###                          VARIABLES                                 ###
##########################################################################

# Use first parameter as unique identifier
system_uuid=$1

# Server settings
server_url=${browser_watchdog_server_url:-"http://ajax.playr.biz/watchdogs/${system_uuid}/command"}
# NOTE: when a return value is added the match logic
#       in request_restart_signal has to be extended
return_value_restart=${browser_watchdog_return_value_restart:-1}
return_value_no_restart=${browser_watchdog_return_value_no_restart:-0}
server_check_interval=${browser_watchdog_server_check_interval:-300}
initial_delay=${browser_watchdog_initial_delay:-60}
log_file_name=${browser_watchdog_log_file_name:-"/var/log/browser_watchdog.log"}

# Add some terminal colors
COLOR_OFF='\033[0m'       # Text reset
COLOR_RED='\033[0;31m'    # Red
COLOR_YELLOW='\033[0;33m' # Yellow
COLOR_BLUE='\033[0;34m'   # Blue
COLOR_GREEN='\033[0;32m'  # Green

##########################################################################
###                          FUNCTIONS                                 ###
##########################################################################

# Use this to write informative log messages to the terminal
log_info() {
    echo -e "[INFO]  - $(date +%F-%T) - $COLOR_BLUE${1}$COLOR_OFF" >> $log_file_name
}

# Use this to write warning messages to the terminal
log_warning() {
    echo -e "[WARN]  - $(date +%F-%T) - $COLOR_YELLOW${1}$COLOR_OFF" >> $log_file_name
}

# Use this to write error messages to the terminal
log_error() {
    echo -e "[ERROR] - $(date +%F-%T) - $COLOR_RED${1}$COLOR_OFF" >> $log_file_name
}

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
    log_info "received command from server: $result_without_spaces"
    # use simple matches since this script should be
    # compatible with the ash whell (busybox)
    if [[ -z $result_without_spaces ]]; then
        echo $return_value_no_restart
    elif [[ "$result_without_spaces" == "$return_value_no_restart" ]]; then
        echo $return_value_no_restart
    elif [[ "$result_without_spaces" == "$return_value_restart" ]]; then
        echo $return_value_restart
    else
        echo $return_value_no_restart
    fi
}

# reboot the computer for linux systems
reboot_machine_linux() {
    sync
    log_info "sync returned: $?"
    # if raspberry pi allow passwordless sudo shutdown else do normal shutdown
    if cat /proc/cpuinfo | grep "Raspberry Pi" &>/dev/null; then
        sudo shutdown --reboot now
    else
        shutdown --reboot now
    fi
    log_info "reboot returned: $?"
}

# reboot the computer for osx systems
reboot_machine_osx() {
    sync
    log_info "sync returned: $?"
    osascript -e 'tell app "System Events" to shut down'
    log_info "reboot returned: $?"
}

# Reboot machine
# Check running OS to decide unix shutdown or OSX shutdown
reboot_machine() {
    log_info "start reboot, uname: $(uname)"
    if [ "$(uname)" == "Darwin" ]; then
        reboot_machine_osx
    else
        reboot_machine_linux
    fi
}

start_watchdog() {
    #sleep before sending out first request allow the browser to be fully booted
    sleep $initial_delay
    while true; do
        log_info "sending request to $server_url"
        if [ "$(request_restart_signal)" -eq "$return_value_restart" ]; then
            log_warning "received reboot command: restarting machine"
            $(reboot_machine)
        fi
        sleep $server_check_interval
    done
}

##########################################################################
###                          EXECUTION                                 ###
##########################################################################
# remove existing log file (simplest way to keep the size
# of the log file to a minimum)
if [[ -f $log_file_name ]]; then
    rm $log_file_name
fi
log_info "##########################################################################"
log_info "###                                                                    ###"
log_info "###                    start browser watchdog script                   ###"
log_info "###                                                                    ###"
log_info "##########################################################################"

log_info "check if system_uuid is present"
if [[ -z $system_uuid ]]; then
    log_error "machine_id is not defined!"
    exit 1
fi

log_info "check if curl is installed"
if ! which curl >/dev/null; then
    log_error "curl not installed on this system, please install curl"
    exit 1
fi

log_info "starting watchdog loop for device $COLOR_GREEN${system_uuid}$COLOR_OFF"
start_watchdog
