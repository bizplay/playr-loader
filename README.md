Playr loader
============

Introduction
------------
The files in this project enable starting up the Google Chrome or Chromium
browser using the playr_loader.html file in order to show digital signage
content in the browser. The playr_loader.html file checks if playr.biz
is available (an internet connection is present) and if so it loads the
requested digital signage channel.

Files that can be used to start up a browser correctly are provided for;
* Windows
  + start a single Chrome browser window; StartChromeForPlayr.cmd
  + start three browser windows (for showing different channels on three
    different screens); StartChromeOnMultipleScreens.cmd
* MacOS
  + start a single Chrome browser window; start-chrome-macos.command
  + start a single Chromium browser window; start-chromium-macos.command
* Linux (generic)
  + start a single Chrome browser window; start-chrome-for-playr.sh
  + start a single Chromium browser window; start-chromium-for-playr.sh
* Raspberry Pi OS
  + start a single Chromium browser window; start-chromium-RaspberryPiOS.sh
You need to check and possibly edit the content of these files to set the
intended channel(s) and possibly other settings. These files contain further
instructions/information.

Files to support setting up Windows on a device so it can be used on a
signage media player:
* DisablePowershellScripts.ps1
* EnablePowershellScripts.ps1
* PrepareForPlayr.ps1

Apart from this readme file the MIT license file is included.