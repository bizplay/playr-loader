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

:: Determine unique device ID
::
for /f "tokens=3" %%a in ('REG QUERY HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography /v MachineGuid ^| findstr /ri "REG_SZ"') do ( set device_id=%%a )
:: Plan b
if not defined device_id (
:: this works since the value we need is in the last line of the output of the command
  for /f "tokens=* USEBACKQ" %%b in ('wmic csproduct get UUID') do ( set device_id=%%b )
)
if not defined device_id (
  set defined=false
) else (
  set device_id=%device_id:~0,36%
  set defined=true
)
:: wnmic default
if "%device_id%" == "00000000-0000-0000-0000-000000000000" ( set defined=false )
:: registry default
if "%device_id%" == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" ( set defined=false )
:: hardware default
if "%device_id%" == "00020003-0004-0005-0006-000700080009" ( set defined=false )
if "%defined%" == "true" ( goto DEVICE_ID_DEFINED )

:: if a default id was found use the industry standard default and add the mac address to make it unique
for /f "tokens=1" %%c in ('getmac ^| findstr /ri "device"') do ( set mac=%%c )
set mac_address=%mac:-=:%
set device_id="00020003-0004-0005-0006-000700080009;%mac_address:~0,17%"

:DEVICE_ID_DEFINED

:: Define the command line options for starting browser
:: set gpu_options="--ignore-gpu-blocklist --enable-experimental-canvas-features --enable-gpu-rasterization --enable-threaded-gpu-rasterization"
set gpu_options=
set persistency_options=
:: --disable-session-crashed-bubble has been deprecated since v57 of Chrome
set no_nagging_options=--disable-features=SameSiteByDefaultCookies,CookiesWithoutSameSiteMustBeSecure --disable-translate --no-first-run --no-default-browser-check --disable-infobars --autoplay-policy=no-user-gesture-required --no-user-gesture-required --disable-session-crashed-bubble

:: Prevent the
:: "Google Chrome didn't shut down correctly"
:: warning when restarting after a crash of Windows, power outage or
:: other non standard way to end Windows.
:: Choose one of the following options. The first only deletes one file
:: the second option deletes all browser data such as cached videos. The
:: second option should only be used on devices that have very little disk space
:: to implement the second option replace the three lines inside the following
:: if clause with this
:: del "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\Default\" /S /Q
if exist "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\%user1%" (
  if exist "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\%user1%\Preferences" (
    del "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\%user1%\Preferences" /Q
  )
)
if exist "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\%user2%" (
  if exist "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\%user2%\Preferences" (
    del "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\%user2%\Preferences" /Q
  )
)
if exist "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\%user3%" (
  if exist "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\%user3%\Preferences" (
    del "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\%user3%\Preferences" /Q
  )
)
:: when using Chromium use one of the two options, see above
:: del "%USERPROFILE%\AppData\Local\Chromium\User Data\Default\" /S /Q
if exist "%USERPROFILE%\AppData\Local\Chromium\User Data\%user1%" (
  if exist "%USERPROFILE%\AppData\Local\Chromium\User Data\%user1%\Preferences" (
    del "%USERPROFILE%\AppData\Local\Chromium\User Data\%user1%\Preferences" /Q
  )
)
if exist "%USERPROFILE%\AppData\Local\Chromium\User Data\%user2%" (
  if exist "%USERPROFILE%\AppData\Local\Chromium\User Data\%user2%\Preferences" (
    del "%USERPROFILE%\AppData\Local\Chromium\User Data\%user2%\Preferences" /Q
  )
)
if exist "%USERPROFILE%\AppData\Local\Chromium\User Data\%user3%" (
  if exist "%USERPROFILE%\AppData\Local\Chromium\User Data\%user3%\Preferences" (
    del "%USERPROFILE%\AppData\Local\Chromium\User Data\%user3%\Preferences" /Q
  )
)
:: when using Microsoft Edge use one of the two options, see above
:: del "%USERPROFILE%\AppData\Local\Chromium\User Data\Default\" /S /Q
if exist "%USERPROFILE%\AppData\Local\Microsoft\Edge\User Data\%user1%" (
  if exist "%USERPROFILE%\AppData\Local\Microsoft\Edge\User Data\%user1%\Preferences" (
    del "%USERPROFILE%\AppData\Local\Microsoft\Edge\User Data\%user1%\Preferences" /Q
  )
)
if exist "%USERPROFILE%\AppData\Local\Microsoft\Edge\User Data\%user2%" (
  if exist "%USERPROFILE%\AppData\Local\Microsoft\Edge\User Data\%user2%\Preferences" (
    del "%USERPROFILE%\AppData\Local\Microsoft\Edge\User Data\%user2%\Preferences" /Q
  )
)
if exist "%USERPROFILE%\AppData\Local\Microsoft\Edge\User Data\%user3%" (
  if exist "%USERPROFILE%\AppData\Local\Microsoft\Edge\User Data\%user3%\Preferences" (
    del "%USERPROFILE%\AppData\Local\Microsoft\Edge\User Data\%user3%\Preferences" /Q
  )
)

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

:: Watchdog
::
:: The watchdog checks for a reboot command on the server and reboots the
:: device if it receives that command
:: TODO; check if browser is still running and kill and restart it if not
::
set watchdog_command=curl -k "https://ajax.playr.biz/watchdogs/%device_id%/command" -o - -s
:: interval for checking the server; 5 minutes
set watchdog_interval_in_sec=300
set reboot_command=1
:: set default response in case the server does not respond (4xx/5xx status code)
set response=2
:: first wait for the player to start properly
timeout /nobreak /t %watchdog_interval_in_sec%

:WATCHDOG_LOOP
:: get command from the server
for /f %%d in ('%watchdog_command%') do ( set response=%%d )
:: remove html/json tag/structure non-word characters
:: to make the following full proof, response should be checked to be
:: defined after each replacement
set response=%response:<=%
set response=%response:>=%
set response=%response:!=%
set response=%response:/=%
set response=%response:[=%
set response=%response:]=%
set response=%response:{=%
set response=%response:}=%
if defined response (
  set watchdog_response=%response:~0,1%
) else (
  set watchdog_response=2
)
if "%reboot_command%" == "%watchdog_response%" (
  echo Rebooting the device...
  shutdown -r
  exit /b 0
) else (
  echo Continueing to check for watchdog command...
  timeout /nobreak /t %watchdog_interval_in_sec%
  goto WATCHDOG_LOOP
)
exit /b 0