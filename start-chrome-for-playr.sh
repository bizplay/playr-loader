#!/bin/bash
# The path to the page that will check internet connection 
# before loading the playr channel
playr_loader_file="/home/webc/playr-loader/playr_loader.html"

if [[ $1 == "" ]]
then
	# enter the channel url below so it is equal to the 
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

google-chrome --no-first-run --no-default-browser-check --disable-translate --disable-session-crashed-bubble --kiosk "file://"${playr_loader_file}"?channel="${channel}"&reload_url="${reload_url}
