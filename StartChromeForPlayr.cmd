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
::
if not DEFINED IS_MINIMIZED (
  set "IS_MINIMIZED=1"
  start "" /min "%~dpnx0" %* 
  exit
)
 
:: Log file for troubleshooting startup issues on signage players
::
set "playr_log=%TEMP%\playr_startup.log"
:: Rotate log when it grows beyond 1 MB
if exist "%playr_log%" (
  for %%F in ("%playr_log%") do if %%~zF geq 1048576 del "%playr_log%"
)
echo.>> "%playr_log%"
echo %date% %time% ===== StartChromeForPlayr =====>> "%playr_log%"
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
echo %date% %time% playr_loader file found at: %playr_loader_file%>> "%playr_log%"

:: use the url below if you want be able to set the channel to play on your dashboard.
:: Note: using this setting requires a one time registration of the playback device
:: using the dashboard (under Settings/Players)
::
set "channel=http://play.playr.biz"

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
:: wnmic defaults
if "%device_id%" == "00000000-0000-0000-0000-000000000000" ( set "defined=false" )
if "%device_id:~0,4%" == "wmic" ( set "defined=false" )
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

:: change and use the url below if you want to play a specific channel that cannot be
:: changed from your dashboard
:: Note: add /en, /nl or other language indication before /xxxx to enforce the
:: use of the correct locale
::
:: set channel=http://playr.biz/xxxx/yyyy

:: Define the command line options for starting browser
:: set gpu_options="--ignore-gpu-blocklist --enable-experimental-canvas-features --enable-gpu-rasterization --enable-threaded-gpu-rasterization"
::
set "gpu_options="
set "persistency_options="
:: --disable-session-crashed-bubble has been deprecated since v57 at the latest
set "no_nagging_options=--disable-features=SameSiteByDefaultCookies,CookiesWithoutSameSiteMustBeSecure --disable-translate --no-first-run --disable-first-run-ui --no-default-browser-check --autoplay-policy=no-user-gesture-required --no-user-gesture-required --disable-search-engine-choice-screen --hide-crash-restore-bubble"

:: Dedicated Playr browser profile - avoids touching the user's normal Chrome/Edge profile.
:: Preventing the "didn't shut down correctly" warning without deleting Preferences, if patching that file is possible.
::
set "playr_profile_dir=%LOCALAPPDATA%\PlayrBrowserProfile"
if not exist "%playr_profile_dir%" mkdir "%playr_profile_dir%"
:: Remove only volatile lock files from the dedicated profile.
:: for %%F in ("%playr_profile_dir%\SingletonLock" "%playr_profile_dir%\SingletonCookie" "%playr_profile_dir%\SingletonSocket") do (
for %%F in ("%playr_profile_dir%\SingletonLock") do (
  if exist %%~F del %%~F /Q >nul 2>nul
)
:: If the dedicated profile has a Preferences file, mark it as cleanly exited or 
:: delete it if patching the content of the file is impossible.
:: Since playback might not work if the Preferences file indicates that the browser 
:: crashed, it is worth taking the risk of deleting it in the exceptional 
:: case that patching it is not possible.
call :PATCH_PLAYR_PROFILE_PREFERENCES

:: Find the browser executable that can be started to show the digital signage content from playr.biz
:: the code below should work after a 'normal' installation of either Google Chrome or Chromium
::
:: if all else fails, use Internet Explorer
set "browser_executable=iexplore.exe"
if exist "%ProgramFiles(x86)%\Internet Explorer\iexplore.exe" (
  set "browser_executable=%ProgramFiles(x86)%\Internet Explorer\iexplore.exe"
)
:: in case even Microsoft Edge cannot be found => default to Microsoft Internet Explorer
:: this will certainly not give the best results, command line parameters might give errors
if exist "%ProgramFiles%\Internet Explorer\iexplore.exe" (
  set "browser_executable=%ProgramFiles%\Internet Explorer\iexplore.exe"
)
if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" (
  set "browser_executable=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
)
:: in case Chrome or Chromium cannot be found => default to Microsoft Edge
:: as up to date versions of that are also Blink (Chromium/Chrome redering engine) based
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
::
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
echo %date% %time% Profile: %playr_profile_dir%>> "%playr_log%"
echo %date% %time% Channel: %channel%>> "%playr_log%"

set "replace=%%20"
set "playr_loader_file_normalized=%playr_loader_file: =!replace!%"
set "app_url=file:///%playr_loader_file_normalized%?channel=%channel%&watchdog_id=%device_id%"
echo %date% %time% URL: !app_url!>> "%playr_log%"
for %%E in ("%browser_executable%") do set "browser_process_name=%%~nxE"
echo %date% %time% Browser process: %browser_process_name%>> "%playr_log%"

:: set mouse pointer to left bottom corner in case css 'mouse: none' does not work
::
rundll32 user32.dll,SetCursorPos

:: Launch the full screen browser
::
call :LAUNCH_PLAYR_BROWSER

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
call :RESTART_BROWSER_IF_NEEDED
echo %date% %time% Continuing watchdog (last server response: %watchdog_response%)>> "%playr_log%"
timeout /nobreak /t %watchdog_interval_in_sec%
goto WATCHDOG_LOOP

:BROWSER_WATCHDOG_LOOP
call :RESTART_BROWSER_IF_NEEDED
timeout /nobreak /t %watchdog_interval_in_sec%
goto BROWSER_WATCHDOG_LOOP

goto :eof

:PATCH_PLAYR_PROFILE_PREFERENCES
set "PLAYR_PROFILE=%playr_profile_dir%"
set "powershell_exe="
if exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" (
  set "powershell_exe=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
)
if not defined powershell_exe if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" (
  set "powershell_exe=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
)
if not defined powershell_exe (
  for /f "delims=" %%P in ('where powershell 2^>nul') do (
    if not defined powershell_exe set "powershell_exe=%%P"
  )
)
if defined powershell_exe (
  echo %date% %time% Patching profile Preferences via PowerShell>> "%playr_log%"
  "%powershell_exe%" -NoProfile -ExecutionPolicy Bypass -Command "$profileDir=$env:PLAYR_PROFILE; $p=Join-Path $profileDir 'Default\Preferences'; if(Test-Path $p){ try { $j=Get-Content -Raw $p | ConvertFrom-Json; if($null -eq $j.profile){ $j | Add-Member -MemberType NoteProperty -Name profile -Value ([pscustomobject]@{}) }; if($j.profile.PSObject.Properties.Name -contains 'exit_type'){ $j.profile.exit_type='Normal' } else { $j.profile | Add-Member -MemberType NoteProperty -Name exit_type -Value 'Normal' }; if($j.profile.PSObject.Properties.Name -contains 'exited_cleanly'){ $j.profile.exited_cleanly=$true } else { $j.profile | Add-Member -MemberType NoteProperty -Name exited_cleanly -Value $true }; $j | ConvertTo-Json -Depth 100 | Set-Content -Encoding UTF8 $p } catch { Rename-Item $p ($p + '.bad.' + (Get-Date -Format 'yyyyMMddHHmmss')) -Force } }" >nul 2>nul
  exit /b 0
)
set "cscript_exe="
if exist "%SystemRoot%\System32\cscript.exe" set "cscript_exe=%SystemRoot%\System32\cscript.exe"
if not defined cscript_exe (
  for /f "delims=" %%C in ('where cscript 2^>nul') do (
    if not defined cscript_exe set "cscript_exe=%%C"
  )
)
if defined cscript_exe (
  echo %date% %time% PowerShell not found; patching Preferences via cscript>> "%playr_log%"
  call :WRITE_PLAYR_PATCH_PREFERENCES
  "%cscript_exe%" //nologo "%TEMP%\playr_patch_preferences.vbs" "%playr_profile_dir%" >nul 2>nul
  exit /b 0
)
echo %date% %time% WARNING: PowerShell and cscript unavailable; deleting Preferences file>> "%playr_log%"
if exist "%playr_profile_dir%\Default" (
  if exist "%playr_profile_dir%\Default\Preferences" (
    del "%playr_profile_dir%\Default\Preferences" /Q
  )
)
exit /b 0

:WRITE_PLAYR_PATCH_PREFERENCES
set "playr_patch_vbs=%TEMP%\playr_patch_preferences.vbs"
if exist "%playr_patch_vbs%" del "%playr_patch_vbs%" /Q >nul 2>nul
(
echo Option Explicit
echo Dim profileDir, prefsPath, fso, ts, content, badName, q
echo profileDir = WScript.Arguments^(0^)
echo prefsPath = profileDir ^& "\Default\Preferences"
echo Set fso = CreateObject^("Scripting.FileSystemObject"^)
echo If Not fso.FileExists^(prefsPath^) Then WScript.Quit 0
echo On Error Resume Next
echo Set ts = fso.OpenTextFile^(prefsPath, 1, False^)
echo content = ts.ReadAll
echo ts.Close
echo If Err.Number ^<^> 0 Then
echo   badName = prefsPath ^& ".bad." ^& Replace^(Replace^(Replace^(CStr^(Now^), ":", ""^), "/", ""^), " ", ""^)
echo   fso.MoveFile prefsPath, badName
echo   WScript.Quit 1
echo End If
echo q = Chr^(34^)
echo content = Replace^(content, q ^& "exited_cleanly" ^& q ^& ":false", q ^& "exited_cleanly" ^& q ^& ":true"^)
echo content = Replace^(content, q ^& "exited_cleanly" ^& q ^& ": false", q ^& "exited_cleanly" ^& q ^& ": true"^)
echo content = Replace^(content, q ^& "exit_type" ^& q ^& ":" ^& q ^& "Crashed" ^& q, q ^& "exit_type" ^& q ^& ":" ^& q ^& "Normal" ^& q^)
echo content = Replace^(content, q ^& "exit_type" ^& q ^& ": " ^& q ^& "Crashed" ^& q, q ^& "exit_type" ^& q ^& ": " ^& q ^& "Normal" ^& q^)
echo content = Replace^(content, q ^& "exit_type" ^& q ^& ":" ^& q ^& "Abnormal" ^& q, q ^& "exit_type" ^& q ^& ":" ^& q ^& "Normal" ^& q^)
echo content = Replace^(content, q ^& "exit_type" ^& q ^& ": " ^& q ^& "Abnormal" ^& q, q ^& "exit_type" ^& q ^& ": " ^& q ^& "Normal" ^& q^)
echo Set ts = fso.OpenTextFile^(prefsPath, 2, False^)
echo ts.Write content
echo ts.Close
echo If Err.Number ^<^> 0 Then
echo   badName = prefsPath ^& ".bad." ^& Replace^(Replace^(Replace^(CStr^(Now^), ":", ""^), "/", ""^), " ", ""^)
echo   fso.MoveFile prefsPath, badName
echo   WScript.Quit 1
echo End If
echo WScript.Quit 0
) > "%playr_patch_vbs%"
exit /b 0

:LAUNCH_PLAYR_BROWSER
echo %date% %time% Launching browser>> "%playr_log%"
start "" "%browser_executable%" %gpu_options% %persistency_options% %no_nagging_options% --user-data-dir="%playr_profile_dir%" --start-fullscreen --kiosk --app="!app_url!"
echo %date% %time% Browser launch requested>> "%playr_log%"
exit /b 0

:RESTART_BROWSER_IF_NEEDED
tasklist /FI "IMAGENAME eq %browser_process_name%" 2>nul | find /I "%browser_process_name%" >nul
if not errorlevel 1 exit /b 0
echo %date% %time% WARNING: %browser_process_name% not running; restarting browser>> "%playr_log%"
call :LAUNCH_PLAYR_BROWSER
exit /b 0
