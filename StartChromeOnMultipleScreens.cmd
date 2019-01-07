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
set playr_loader_file=%USERPROFILE%/Desktop/playr_loader.html

:: use the url below if you want be able to set the channel to play on your dashboard.
:: Note: using this setting requires a one time registration of the playback device
:: using the dashboard (under Settings/Players)
::
set channel1=http://play.playr.biz
set channel2=http://play.playr.biz
set channel3=http://play.playr.biz

:: use three different user profiles to enable starting/running three instances
:: of the Chrome browser at the same time
set user1=Screen1
set user2=Screen2
set user3=Screen3

:: change and use the url below if you want to play a specific channel that cannot be
:: changed from your dashboard
:: Note: add /en, /nl or other language indication before /xxxx to enforce the
:: use of the correct locale
::
:: set channel1=http://playr.biz/xxxx/yyyy
:: set channel2=http://playr.biz/xxxx/zzzz
:: set channel3=http://playr.biz/xxxx/aaaa

:: Define the command line options for starting browser
:: gpu_options="--ignore-gpu-blacklist --enable-experimental-canvas-features --enable-gpu-rasterization --enable-threaded-gpu-rasterization"
::
set gpu_options=
set persistency_options=
:: --disable-session-crashed-bubble has been deprecated since v57 of Chrome
set no_nagging_options=--disable-translate --no-first-run --no-default-browser-check --disable-infobars --autoplay-policy=no-user-gesture-required --no-user-gesture-required --disable-session-crashed-bubble

:: Prevent the
:: "Google Chrome didn't shut down correctly"
:: warning when restarting after a crash of Windows, power outage or
:: other non standard way to end Windows.
:: Choose one of the following options. The first only deletes one file
:: the second option deletes all browser data such as cached videos. The
:: second option should only be used on devices that have very little disk space
::
del "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\%user1%\Preferences" /Q
:: del "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\%user1%\" /S /Q
del "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\%user2%\Preferences" /Q
:: del "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\%user2%\" /S /Q
del "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\%user3%\Preferences" /Q
:: del "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\%user3%\" /S /Q

:: change the paths below to point at the different chrome.exe's that are installed on your computer
:: you can find the path to the chrome.exe by right clicking the (desktop) icon  of Chrome/Chrome Canary/Chromium, choosing properties
:: and looking in the Target field.
:: the code below should work after a normal installation of Google Chrome
::
if exist %ProgramFiles%\Google\Chrome\Application\chrome.exe (
  set google_chrome_path="%ProgramFiles%\Google\Chrome\Application\chrome.exe"

) else (
  set google_chrome_path="%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
)

:: The window positions specified below will work when you use three 1080p screens (1920x1080)
:: If you use screens with a different resolution you may need to change the values below.
::
screen_position1=50,20
screen_position2=2000,20
screen_position3=4000,20

:: The code below should work as is and should not require any changes
::
setlocal enabledelayedexpansion
set replace=%%20
set playr_loader_file_normalized=%playr_loader_file: =!replace!%
start /min cmd /c "%google_chrome_path% --profile-directory=%user1% --chrome-frame %gpu_options% %persistency_options% %no_nagging_options% --window-position=%screen_position1% --kiosk file:///%playr_loader_file_normalized%?channel=%channel1%"
start /min cmd /c "%google_chrome_path% --profile-directory=%user2% --chrome-frame %gpu_options% %persistency_options% %no_nagging_options% --window-position=%screen_position2% --kiosk file:///%playr_loader_file_normalized%?channel=%channel2%"
start /min cmd /c "%google_chrome_path% --profile-directory=%user3% --chrome-frame %gpu_options% %persistency_options% %no_nagging_options% --window-position=%screen_position3% --kiosk file:///%playr_loader_file_normalized%?channel=%channel3%"
