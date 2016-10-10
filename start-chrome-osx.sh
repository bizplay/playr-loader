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

# The path to the page that will check internet connection 
# before loading the playr channel
playr_loader_file="/Users/user-name/playr_loader/playr_loader.html"

if [[ $1 == "" ]]
then
	# use the generic URL below for ease of use
	# or use the channel url that is shown as
	# Playback Address on your dashboard
	channel="http://play.playr.biz"
else
	channel=$1
fi

if [[ $2 == "" ]]
then
	# enter the location of the playr-loader.html file
	reload_url=file://${playr_loader_file}
else
	reload_url=file://$2
fi

# to check the values of the variables created above uncomment the following line
# echo "file://"${playr_loader_file}"?channel="${channel}"&reload_url="${reload_url}
open -a "/Applications/Google Chrome.app" --args --no-first-run --no-default-browser-check --disable-translate --disable-session-crashed-bubble --kiosk "file://"${playr_loader_file}"?channel="${channel}"&reload_url="${reload_url}
