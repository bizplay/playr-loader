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
# NOTE: for Chromium use "/Applications/Chromium.app"
browser="Chromium.app"

# Define the command line options for starting browser
# gpu_options="--ignore-gpu-blacklist --enable-experimental-canvas-features --enable-gpu-rasterization --enable-threaded-gpu-rasterization"
gpu_options=""
persistency_options=""
# --disable-session-crashed-bubble has been deprecated since v57 at the latest
no_nagging_options="--disable-translate --no-first-run --no-default-browser-check --disable-infobars --autoplay-policy=no-user-gesture-required --no-user-gesture-required --disable-session-crashed-bubble"

# The path to the page that will check internet connection
# before loading the actual signage channel
# NOTE: check the location of the player_loader.html in the following line
execution_path=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
playr_loader_file="${execution_path}/playr_loader.html"

# The URL that will be played in the browser
if [[ $1 == "" ]]
then
	# use the generic URL below for ease of use
	# or use the channel url that is shown as
	# 'Playback Address' on your dashboard
	channel="http://play.playr.biz"
else
	channel=$1
fi
# Escape special characters so any parameters of the channel url
# and reload_url will be processed correctly by the player_loader_file
channel=$(echo "$channel" | sed 's:%:%25:g;s:?:%3F:g;s:&:%26:g;s:=:%3D:g;s: :%20:g;s_:_%3A_g;s:/:%2F:g;s:;:%3B:g;s:@:%40:g;s:+:%2B:g;s:,:%2C:g;s:#:%23:g')

if [[ $2 == "" ]]
then
	# enter the location of the playr-loader.html file
	reload_url=file://${playr_loader_file}
else
	reload_url=file://$2
fi

# another way to prevent "Chrome didn shut down correclty" overlay on the screen
sed -i 's/exit_type\"\:\"Crashed/exit_type\"\:\"Normal/g' ~/Library/Application Support/Chromium/Default/Preferences
sed -i 's/exit_type\"\:\"SessionEnded/exit_type\"\:\"Normal/g' ~/Library/Application Support/Chromium/Default/Preferences
sed -i 's/exited_cleanly\"\:false/exited_cleanly\"\:true/g' ~/Library/Application Support/Chromium/Default/Preferences

# to check the values of the variables created above uncomment the following line
echo "file://"${playr_loader_file}"?channel="${channel}"&reload_url="${reload_url}
open -a "$browser" --args ${gpu_options} ${persistency_options} ${no_nagging_options} --kiosk "file://"${playr_loader_file}"?channel="${channel}"&reload_url="${reload_url}
