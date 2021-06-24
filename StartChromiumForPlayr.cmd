@echo off
::
:: This batch file is provided to show digital signage content from playr.biz
:: To read more on the purpose of this file and how to use it
:: see the accompanying README.md file or
:: contact your digital signage provider.
::
:: This file is licensed under the MIT license.
::
:: THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
:: EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
:: OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
:: NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
:: HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
:: WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
:: FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
:: OTHER DEALINGS IN THE SOFTWARE.

:: make sure that the path to the playr_loader.html file is correct in your situation
:: %USERPROFILE% points to your personal profile directory, that usually can be found
:: at C:\Users\<your user name>
::
set playr_loader_file=%USERPROFILE%\Desktop\playr_loader.html

:: use the url below if you want be able to set the channel to play on your dashboard.
:: Note: using this setting requires a one time registration of the playback device
:: using the dashboard (under Settings/Players)
::
set channel=http://play.playr.biz

:: change and use the url below if you want to play a specific channel that cannot be
:: changed from your dashboard
:: Note: add /en, /nl or other language indication before /xxxx to enforce the
:: use of the correct locale
::
:: set channel=http://playr.biz/xxxx/yyyy

:: Define the command line options for starting browser
:: set gpu_options="--ignore-gpu-blocklist --enable-experimental-canvas-features --enable-gpu-rasterization --enable-threaded-gpu-rasterization"
set gpu_options=
set persistency_options=
:: --disable-session-crashed-bubble has been deprecated since v57 at the latest
set no_nagging_options=--disable-features=SameSiteByDefaultCookies,CookiesWithoutSameSiteMustBeSecure --disable-translate --no-first-run --no-default-browser-check --disable-infobars --autoplay-policy=no-user-gesture-required --no-user-gesture-required --disable-session-crashed-bubble

:: The code below should work as is and should not require any changes
::
setlocal enabledelayedexpansion
set replace=%%20
set playr_loader_file_normalized=%playr_loader_file: =!replace!%

:: The --app= option prevents the "Restore pages" popup from showing up after the previous process was killed
"%USERPROFILE%\Desktop\Chromium\chrome.exe" %gpu_options% %persistency_options% %no_nagging_options% --kiosk --app="file:///%playr_loader_file_normalized%?channel=%channel%"
