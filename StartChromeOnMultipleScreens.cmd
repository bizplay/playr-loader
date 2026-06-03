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
@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: Restart this script minimized (ref: https://stackoverflow.com/a/22357573/414376)
if not DEFINED IS_MINIMIZED (
  set "IS_MINIMIZED=1"
  start "" /min "%~dpnx0" %*
  exit
)
 

:: Log file for troubleshooting startup issues on signage players
set "playr_log=%TEMP%\playr_startup.log"
:: Rotate log when it grows beyond 1 MB
if exist "%playr_log%" (
  for %%F in ("%playr_log%") do if %%~zF geq 1048576 del "%playr_log%"
)
echo.>> "%playr_log%"
echo %date% %time% ===== StartChromeOnMultipleScreens =====>> "%playr_log%"
echo %date% %time% Script: %~f0>> "%playr_log%"

:: Locate playr_loader.html on the local Desktop or the OneDrive Desktop
:: %USERPROFILE% points to your personal profile directory, that usually can be found
:: at C:\Users\<your user name>
::
set "playr_loader_desktop=%USERPROFILE%\Desktop\playr_loader.html"
set "playr_loader_onedrive=%USERPROFILE%\OneDrive\Desktop\playr_loader.html"
if exist "%playr_loader_desktop%" (
  set "playr_loader_file=%playr_loader_desktop%"
) else if exist "%playr_loader_onedrive%" (
  set "playr_loader_file=%playr_loader_onedrive%"
) else (
  echo %date% %time% ERROR: playr_loader.html not found at:>> "%playr_log%"
  echo %date% %time%   %playr_loader_desktop%>> "%playr_log%"
  echo %date% %time%   %playr_loader_onedrive%>> "%playr_log%"
  echo ERROR: playr_loader.html not found at:
  echo   %playr_loader_desktop%
  echo   %playr_loader_onedrive%
  timeout /t 30 >nul
  exit /b 1
)
echo %date% %time% Loader: %playr_loader_file%>> "%playr_log%"

:: use the url below if you want be able to set the channel to play on your dashboard.
:: Note: using this setting requires a one time registration of the playback device
:: using the dashboard (under Settings/Players)
::
set "channel1=http://play.playr.biz"
set "channel2=http://play.playr.biz"
set "channel3=http://play.playr.biz"

:: use three different user profiles to enable starting/running three instances
:: of the Chrome browser at the same time
set "user1=Screen1"
set "user2=Screen2"
set "user3=Screen3"

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
set "device_id="
for /f "tokens=3" %%a in ('REG QUERY HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography /v MachineGuid ^| findstr /ri "REG_SZ"') do ( set "device_id=%%a" )
:: Plan b
if not defined device_id (
:: this works since the value we need is in the last line of the output of the command
  for /f "tokens=* USEBACKQ" %%b in ('wmic csproduct get UUID') do ( set "device_id=%%b" )
)
if not defined device_id (
  set "defined=false"
) else (
  set "device_id=%device_id:~0,36%"
  set "defined=true"
)
:: wnmic default
if "%device_id%" == "00000000-0000-0000-0000-000000000000" ( set "defined=false" )
if /i "%device_id:~0,4%" == "wmic" ( set "defined=false" )
:: registry default
if "%device_id%" == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" ( set "defined=false" )
:: hardware default
if "%device_id%" == "00020003-0004-0005-0006-000700080009" ( set "defined=false" )
if "%defined%" == "true" ( goto DEVICE_ID_DEFINED )

:: if a default id was found use the industry standard default and add the mac address to make it unique
for /f "tokens=1" %%c in ('getmac ^| findstr /ri "device"') do ( set "mac=%%c" )
set "mac_address=%mac:-=:%"
set "device_id=00020003-0004-0005-0006-000700080009;%mac_address:~0,17%"

:DEVICE_ID_DEFINED
echo %date% %time% Device ID: %device_id%>> "%playr_log%"

:: Define the command line options for starting browser
:: set gpu_options="--ignore-gpu-blocklist --enable-experimental-canvas-features --enable-gpu-rasterization --enable-threaded-gpu-rasterization"
set "gpu_options="
set "persistency_options="
  :: --disable-session-crashed-bubble has been deprecated since v57 at the latest
set "no_nagging_options=--disable-features=SameSiteByDefaultCookies,CookiesWithoutSameSiteMustBeSecure --disable-translate --no-first-run --disable-first-run-ui --no-default-browser-check --autoplay-policy=no-user-gesture-required --no-user-gesture-required --disable-search-engine-choice-screen"

:: Prevent the
:: "Google Chrome didn't shut down correctly"
:: warning when restarting after a crash of Windows, power outage or
:: other non standard way to end Windows.
:: Note: %LOCALAPPDATA% is equal to %USERPROFILE%\AppData\Local
:: Choose one of the following options. The first only deletes one file
:: the second option deletes all browser data such as cached videos. The
:: second option should only be used on devices that have very little disk space
:: to implement the second option replace the three lines inside the following
:: if clause with this
:: del "%LOCALAPPDATA%\Google\Chrome\User Data\Default\" /S /Q
if exist "%LOCALAPPDATA%\Google\Chrome\User Data\Default" (
  if exist "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Preferences" (
    del "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Preferences" /Q
  )
)
if exist "%LOCALAPPDATA%\Google\Chrome\User Data\" (
  if exist "%LOCALAPPDATA%\Google\Chrome\User Data\SingletonLock" (
    del "%LOCALAPPDATA%\Google\Chrome\User Data\SingletonLock" /Q
  )
)
if exist "%LOCALAPPDATA%\Google\Chrome\User Data\%user1%" (
  if exist "%LOCALAPPDATA%\Google\Chrome\User Data\%user1%\Preferences" (
    del "%LOCALAPPDATA%\Google\Chrome\User Data\%user1%\Preferences" /Q
  )
)
if exist "%LOCALAPPDATA%\Google\Chrome\User Data\%user2%" (
  if exist "%LOCALAPPDATA%\Google\Chrome\User Data\%user2%\Preferences" (
    del "%LOCALAPPDATA%\Google\Chrome\User Data\%user2%\Preferences" /Q
  )
)
if exist "%LOCALAPPDATA%\Google\Chrome\User Data\%user3%" (
  if exist "%LOCALAPPDATA%\Google\Chrome\User Data\%user3%\Preferences" (
    del "%LOCALAPPDATA%\Google\Chrome\User Data\%user3%\Preferences" /Q
  )
)
:: when using Chromium use one of the two options, see above
:: del "%LOCALAPPDATA%\Chromium\User Data\Default\" /S /Q
if exist "%LOCALAPPDATA%\Chromium\User Data\Default" (
  if exist "%LOCALAPPDATA%\Chromium\User Data\Default\Preferences" (
    del "%LOCALAPPDATA%\Chromium\User Data\Default\Preferences" /Q
  )
)
if exist "%LOCALAPPDATA%\Chromium\User Data\" (
  if exist "%LOCALAPPDATA%\Chromium\User Data\SingletonLock" (
    del "%LOCALAPPDATA%\Chromium\User Data\SingletonLock" /Q
  )
)
if exist "%LOCALAPPDATA%\Chromium\User Data\%user1%" (
  if exist "%LOCALAPPDATA%\Chromium\User Data\%user1%\Preferences" (
    del "%LOCALAPPDATA%\Chromium\User Data\%user1%\Preferences" /Q
  )
)
if exist "%LOCALAPPDATA%\Chromium\User Data\%user2%" (
  if exist "%LOCALAPPDATA%\Chromium\User Data\%user2%\Preferences" (
    del "%LOCALAPPDATA%\Chromium\User Data\%user2%\Preferences" /Q
  )
)
if exist "%LOCALAPPDATA%\Chromium\User Data\%user3%" (
  if exist "%LOCALAPPDATA%\Chromium\User Data\%user3%\Preferences" (
    del "%LOCALAPPDATA%\Chromium\User Data\%user3%\Preferences" /Q
  )
)
:: when using Microsoft Edge use one of the two options, see above
:: del "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\" /S /Q
if exist "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default" (
  if exist "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Preferences" (
    del "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Preferences" /Q
  )
)
if exist "%LOCALAPPDATA%\Microsoft\Edge\User Data\" (
  if exist "%LOCALAPPDATA%\Microsoft\Edge\User Data\SingletonLock" (
    del "%LOCALAPPDATA%\Microsoft\Edge\User Data\SingletonLock" /Q
  )
)
if exist "%LOCALAPPDATA%\Microsoft\Edge\User Data\%user1%" (
  if exist "%LOCALAPPDATA%\Microsoft\Edge\User Data\%user1%\Preferences" (
    del "%LOCALAPPDATA%\Microsoft\Edge\User Data\%user1%\Preferences" /Q
  )
)
if exist "%LOCALAPPDATA%\Microsoft\Edge\User Data\%user2%" (
  if exist "%LOCALAPPDATA%\Microsoft\Edge\User Data\%user2%\Preferences" (
    del "%LOCALAPPDATA%\Microsoft\Edge\User Data\%user2%\Preferences" /Q
  )
)
if exist "%LOCALAPPDATA%\Microsoft\Edge\User Data\%user3%" (
  if exist "%LOCALAPPDATA%\Microsoft\Edge\User Data\%user3%\Preferences" (
    del "%LOCALAPPDATA%\Microsoft\Edge\User Data\%user3%\Preferences" /Q
  )
)

:: the code below should work after a 'normal' installation of either Google Chrome or Chromium
::
:: in case Chrome or Chromium cannot be found => default to Microsoft Edge
:: as up to date versions of that are also Blink (Chromium/Chrome redering engine) based
set "browser_executable=iexplore.exe"
if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" (
  set "browser_executable=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
)
if exist "%LOCALAPPDATA%\Chromium\Application\chrome.exe" (
  set "browser_executable=%LOCALAPPDATA%\Chromium\Application\chrome.exe"
)
if exist "%ProgramFiles(x86)%\Chromium\chrome.exe" (
  set "browser_executable=%ProgramFiles(x86)%\Chromium\chrome.exe"
)
if exist "%ProgramFiles%\Chromium\chrome.exe" (
  set "browser_executable=%ProgramFiles%\Chromium\chrome.exe"
)
if exist "%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe" (
  set "browser_executable=%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"
)
if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" (
  set "browser_executable=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
)
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" (
  set "browser_executable=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
)

:: Pre-flight: browser executable must exist
if not exist "%browser_executable%" (
  where "%browser_executable%" >nul 2>nul
  if errorlevel 1 (
    echo %date% %time% ERROR: Browser not found: %browser_executable%>> "%playr_log%"
    echo ERROR: Browser not found: %browser_executable%
    timeout /t 30 >nul
    exit /b 1
  )
)
echo %browser_executable% | findstr /i /c:"chrome.exe" /c:"msedge.exe" /c:"chromium" >nul
if errorlevel 1 (
  echo %date% %time% WARNING: Non-Chromium browser selected; kiosk flags may not work>> "%playr_log%"
)
echo %date% %time% Browser: %browser_executable%>> "%playr_log%"
echo %date% %time% Channels: %channel1% | %channel2% | %channel3%>> "%playr_log%"



:: The window positions specified below will work when you use three 1080p screens (1920x1080)
:: If you use screens with a different resolution you may need to change the values below.
::
set "screen_position1=50,20"
set "screen_position2=2000,20"
set "screen_position3=4000,20"

:: The code below should work as is and should not require any changes
::
set "replace=%%20"
set "playr_loader_file_normalized=%playr_loader_file: =!replace!%"
set "app_url1=file:///%playr_loader_file_normalized%?channel=%channel1%"
set "app_url2=file:///%playr_loader_file_normalized%?channel=%channel2%"
set "app_url3=file:///%playr_loader_file_normalized%?channel=%channel3%"
echo %date% %time% URL1: !app_url1!>> "%playr_log%"
echo %date% %time% URL2: !app_url2!>> "%playr_log%"
echo %date% %time% URL3: !app_url3!>> "%playr_log%"
for %%E in ("%browser_executable%") do set "browser_process_name=%%~nxE"
echo %date% %time% Browser process: %browser_process_name% (expect 3 instances)>> "%playr_log%"

:: set mouse pointer to left bottom corner in case css 'mouse: none' does not work
::
rundll32 user32.dll,SetCursorPos

call :LAUNCH_PLAYR_BROWSERS

:: Watchdog: remote reboot command (curl) and local browser restart loop
::
set "watchdog_interval_in_sec=300"
set "watchdog_response_file=%TEMP%\playr_watchdog_response.txt"
set "reboot_command=1"
set "watchdog_url=https://ajax.playr.biz/watchdogs/%device_id%/command"
set "watchdog_remote_enabled=1"
where curl >nul 2>nul
if errorlevel 1 (
  set "watchdog_remote_enabled=0"
  echo %date% %time% WARNING: curl not found; remote reboot watchdog disabled>> "%playr_log%"
  echo WARNING: curl not found. Remote reboot disabled; browser restart loop active. See %playr_log%
) else (
  echo %date% %time% Watchdog: remote poll every %watchdog_interval_in_sec%s>> "%playr_log%"
)
echo %date% %time% Watchdog: browser check every %watchdog_interval_in_sec%s>> "%playr_log%"
:: first wait for the player to start properly
timeout /nobreak /t %watchdog_interval_in_sec%

if "%watchdog_remote_enabled%"=="0" goto BROWSER_WATCHDOG_LOOP

:WATCHDOG_LOOP
:: default when the server does not respond or curl fails
set "response=2"
if exist "%watchdog_response_file%" del "%watchdog_response_file%" /Q >nul 2>nul
curl -k "%watchdog_url%" -o "%watchdog_response_file%" -s
if errorlevel 1 (
  echo %date% %time% WARNING: curl failed, errorlevel %errorlevel%>> "%playr_log%"
) else if exist "%watchdog_response_file%" (
  for /f "usebackq delims=" %%d in ("%watchdog_response_file%") do set "response=%%d"
) else (
  echo %date% %time% WARNING: curl returned no response file>> "%playr_log%"
)
:: remove html/json tag/structure non-word characters
set "response=%response:<=%"
set "response=%response:>=%"
set "response=%response:!=%"
set "response=%response:/=%"
set "response=%response:[=%"
set "response=%response:]=%"
set "response=%response:{=%"
set "response=%response:}=%"
if defined response (
  set "watchdog_response=%response:~0,1%"
) else (
  set "watchdog_response=2"
)
if "%reboot_command%"=="%watchdog_response%" (
  echo %date% %time% Reboot command received from server>> "%playr_log%"
  echo Rebooting the device in 30 seconds...
  shutdown /r /t 30
  exit /b 0
)
call :RESTART_BROWSERS_IF_NEEDED
echo %date% %time% Continuing watchdog (last server response: %watchdog_response%)>> "%playr_log%"
timeout /nobreak /t %watchdog_interval_in_sec%
goto WATCHDOG_LOOP

:BROWSER_WATCHDOG_LOOP
call :RESTART_BROWSERS_IF_NEEDED
timeout /nobreak /t %watchdog_interval_in_sec%
goto BROWSER_WATCHDOG_LOOP

goto :eof

:LAUNCH_PLAYR_BROWSERS
echo %date% %time% Launching multi-screen browsers>> "%playr_log%"
start "" "%browser_executable%" --profile-directory=%user1% --chrome-frame %gpu_options% %persistency_options% %no_nagging_options% --window-position=%screen_position1% --kiosk --app="!app_url1!"
start "" "%browser_executable%" --profile-directory=%user2% --chrome-frame %gpu_options% %persistency_options% %no_nagging_options% --window-position=%screen_position2% --kiosk --app="!app_url2!"
start "" "%browser_executable%" --profile-directory=%user3% --chrome-frame %gpu_options% %persistency_options% %no_nagging_options% --window-position=%screen_position3% --kiosk --app="!app_url3!"
echo %date% %time% Browser launch requested for all screens>> "%playr_log%"
exit /b 0

:RESTART_BROWSERS_IF_NEEDED
set "browser_instance_count=0"
for /f %%a in ('tasklist /FI "IMAGENAME eq %browser_process_name%" /NH 2^>nul ^| find /c /I "%browser_process_name%"') do set "browser_instance_count=%%a"
if !browser_instance_count! geq 3 exit /b 0
echo %date% %time% WARNING: expected 3 %browser_process_name% instances, found !browser_instance_count!; restarting all screens>> "%playr_log%"
call :LAUNCH_PLAYR_BROWSERS
exit /b 0
