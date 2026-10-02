:: This batch file is provided to show digital signage content from playr.biz
:: To read more on the purpose of this file and how to use it
:: see the accompanying README.md file or
:: contact your digital signage provider.
::
:: This script is targetting Windows 7 and later. 
:: It should work on Windows Vista,
:: Windows XP misses a number of commands  which means that this script 
:: should NOT be used it that version of Windows.
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

rem cmd.exe cannot resolve labels (:LOG, :WAIT_SECONDS, ...) when this file has
rem Unix LF line endings. GitHub "Download ZIP" serves LF when the repo is
rem maintained on macOS or Linux; .gitattributes does not apply to that zip.
rem This block must not CALL a label or GOTO. It writes a CRLF copy and runs that.
rem Do not CALL the copy: transferring avoids this LF copy running as well.
set "PLAYR_HANDOFF="
if not defined PLAYR_SOURCE set "PLAYR_SOURCE=%~f0"
if not defined PLAYR_CRLF_HELPER set "PLAYR_CRLF_HELPER=%~dp0EnsureCmdLineEndings.ps1"
set "PLAYR_FIXED=%TEMP%\PlayrLaunch\%~nx0"
set "PLAYR_GO=%TEMP%\PlayrLaunch\%~nx0.go"
if /I "%~f0"=="%PLAYR_FIXED%" del "%PLAYR_GO%" 2>nul
if exist "%PLAYR_CRLF_HELPER%" if exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%PLAYR_CRLF_HELPER%" "%~f0" "%PLAYR_FIXED%" "%PLAYR_GO%" "%PLAYR_SOURCE%"
if exist "%PLAYR_GO%" set "PLAYR_HANDOFF=1"
if "%PLAYR_HANDOFF%"=="1" echo Playr: Unix line endings detected. Continuing from "%PLAYR_FIXED%"
if "%PLAYR_HANDOFF%"=="1" "%PLAYR_FIXED%" %*
if "%PLAYR_HANDOFF%"=="1" exit /b 0

if not DEFINED IS_MINIMIZED (
  set "IS_MINIMIZED=1"
  start "" /min "%~dpnx0" %* 
  exit
)

:: Prevent a second Task Scheduler / manual start from running another watchdog.
:: After a hard kill, delete "%TEMP%\playr_single_watchdog.lockdir" if a new start exits immediately.
set "playr_watchdog_lockdir=%TEMP%\playr_single_watchdog.lockdir"
mkdir "%playr_watchdog_lockdir%" 2>nul
if errorlevel 1 (
  echo Playr watchdog lock in use ^(%playr_watchdog_lockdir%^); exiting.
  echo If no Playr watchdog should be running, delete that folder and start again.
  exit /b 0
)
 
:: Log file for troubleshooting startup issues on signage players
::
set "playr_log=%TEMP%\playr_startup.log"
:: Rotate log when it grows beyond 1 MB
if exist "%playr_log%" (
  for %%F in ("%playr_log%") do if %%~zF geq 1048576 del "%playr_log%"
)
echo.>> "%playr_log%"
call :LOG "===== StartChromeForPlayr ====="
call :LOG "Script: %PLAYR_SOURCE%"
if /I not "%~f0"=="%PLAYR_SOURCE%" call :LOG "Running CRLF copy of that script: %~f0"
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
  call :LOG "ERROR: playr_loader.html not found at:"
  call :LOG "  %playr_loader_desktop%"
  call :LOG "  %playr_loader_onedrive%"
  echo ERROR: playr_loader.html not found at:
  echo   %playr_loader_desktop%
  echo   %playr_loader_onedrive%
  call :WAIT_SECONDS 30
  exit /b 1
)
call :LOG "playr_loader file found at: %playr_loader_file%"
:: use the url below if you want be able to set the channel to play on your dashboard.
:: Note: using this setting requires a one time registration of the playback device
:: using the dashboard (under Settings/Players)
::
set "channel=http://play.playr.biz"

:: Determine unique device ID
::
set "device_id="
set "defined=false"
for /f "tokens=3" %%a in ('REG QUERY HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography /v MachineGuid ^| findstr /ri "REG_SZ"') do set "device_id=%%a"
set "device_id=%device_id: =%"

:: Plan B - hardware UUID via PowerShell (replaces deprecated wmic)
:: Done in a subroutine (not a nested for /f `"%powershell_exe%" ...`) to avoid the cmd /c
:: outer-quote-stripping bug that yields "syntax of the filename ... is incorrect".
if not defined device_id call :RESOLVE_DEVICE_ID_VIA_POWERSHELL

if defined device_id (
  set "device_id=!device_id:~0,36!"
  set "defined=true"
)
if "%device_id%" == "00000000-0000-0000-0000-000000000000" set "defined=false"
if /i "%device_id:~0,4%" == "wmic" set "defined=false"
if /i "%device_id%" == "UUID" set "defined=false"
if "%device_id%" == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" set "defined=false"
if "%device_id%" == "00020003-0004-0005-0006-000700080009" set "defined=false"
if "%defined%" == "true" goto DEVICE_ID_DEFINED

:: Plan C - MAC fallback (getmac CSV, locale-independent)
set "mac_address="
for /f "tokens=1 delims=," %%m in ('getmac /fo csv /nh 2^>nul') do (
  if not defined mac_address set "mac_address=%%~m"
)
set "mac_address=!mac_address:-=:!"
set "device_id=00020003-0004-0005-0006-000700080009;!mac_address:~0,17!"

:DEVICE_ID_DEFINED
call :LOG "Device ID: %device_id%"
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

:: Find browser: Chrome -> Chromium -> Edge -> Internet Explorer (legacy fallback)
:: Expand Program Files (x86) once; use pf86 in paths and !browser_executable! inside ( ) blocks.
::
set "pf86=%ProgramFiles(x86)%"
set "browser_executable="

:: Prefer Chrome
if exist "%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe" set "browser_executable=%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"
if not defined browser_executable if exist "%pf86%\Google\Chrome\Application\chrome.exe" set "browser_executable=%pf86%\Google\Chrome\Application\chrome.exe"
if not defined browser_executable if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "browser_executable=%ProgramFiles%\Google\Chrome\Application\chrome.exe"

:: Then Chromium
if not defined browser_executable if exist "%LOCALAPPDATA%\Chromium\Application\chrome.exe" set "browser_executable=%LOCALAPPDATA%\Chromium\Application\chrome.exe"
if not defined browser_executable if exist "%pf86%\Chromium\chrome.exe" set "browser_executable=%pf86%\Chromium\chrome.exe"
if not defined browser_executable if exist "%ProgramFiles%\Chromium\chrome.exe" set "browser_executable=%ProgramFiles%\Chromium\chrome.exe"

:: Then Edge (Chromium-based on supported Windows versions)
if not defined browser_executable if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" set "browser_executable=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
if not defined browser_executable if exist "%pf86%\Microsoft\Edge\Application\msedge.exe" set "browser_executable=%pf86%\Microsoft\Edge\Application\msedge.exe"

:: Last resort: Internet Explorer (legacy Windows only)
if not defined browser_executable if exist "%pf86%\Internet Explorer\iexplore.exe" set "browser_executable=%pf86%\Internet Explorer\iexplore.exe"
if not defined browser_executable if exist "%ProgramFiles%\Internet Explorer\iexplore.exe" set "browser_executable=%ProgramFiles%\Internet Explorer\iexplore.exe"

if not defined browser_executable (
  call :LOG "ERROR: No supported browser found"
  echo ERROR: No supported browser found
  call :WAIT_SECONDS 30
  exit /b 1
)

:: Pre-flight: browser executable must exist (!var! avoids ")" in "(x86)" breaking IF blocks)
::
if not exist "!browser_executable!" (
  where "!browser_executable!" >nul 2>nul
  if errorlevel 1 (
    call :LOG "ERROR: Browser not found: !browser_executable!"
    echo ERROR: Browser not found: !browser_executable!
    call :WAIT_SECONDS 30
    exit /b 1
  )
)
echo !browser_executable! | findstr /i /c:"iexplore.exe" >nul && call :LOG "WARNING: Using Internet Explorer fallback; kiosk flags may not work"
call :LOG "Browser: %browser_executable%"
call :LOG "Profile: %playr_profile_dir%"
call :LOG "Channel: %channel%"
set "replace=%%20"
set "playr_loader_file_normalized=%playr_loader_file: =!replace!%"
:: escaping the & by either url-encoding it (%%26) or by using ^&  for cmd echo/start
:: does not work when starting Chrome from the command line as is doen later in this file
set "app_url=file:///%playr_loader_file_normalized%?channel=%channel%&watchdog_id=%device_id%"
call :LOG "URL: !app_url!"
for %%E in ("%browser_executable%") do set "browser_process_name=%%~nxE"
call :LOG "Browser process: %browser_process_name%"
:: set mouse pointer to left bottom corner in case css 'mouse: none' does not work
::
rundll32 user32.dll,SetCursorPos

:: Launch the full screen browser
::
call :LAUNCH_PLAYR_BROWSER

:: Watchdog: remote reboot command (curl) and local browser restart loop
::
set "watchdog_remote_poll_interval_in_sec=305"
set "watchdog_browser_check_interval_in_sec=60"
set "watchdog_response_file=%TEMP%\playr_watchdog_response.txt"
set "watchdog_http_status_file=%TEMP%\playr_watchdog_http_status.txt"
set "reboot_command=1"
call :ENCODE_DEVICE_ID_FOR_URL
:: Use delayed expansion (!var!) here: device_id_encoded may contain literal % sequences
:: (e.g. %3A) from URL-encoding. Percent expansion (%var%) would mis-pair those % signs
:: with %playr_log% on the same line and corrupt the command (breaks on non-English Windows).
set "watchdog_url=https://ajax.playr.biz/watchdogs/!device_id_encoded!/command"
call :LOG "Watchdog device id (encoded): !device_id_encoded!"
set "watchdog_remote_enabled=1"
where curl >nul 2>nul
if errorlevel 1 (
  set "watchdog_remote_enabled=0"
  call :LOG "WARNING: curl not found; remote reboot watchdog disabled"
  echo WARNING: curl not found. Remote reboot disabled; browser restart loop active. See %playr_log%
) else (
  call :LOG "Watchdog: remote poll every %watchdog_remote_poll_interval_in_sec%s"
)
call :LOG "Watchdog: browser check every %watchdog_browser_check_interval_in_sec%s"
:: first wait for the player to start properly
call :WAIT_SECONDS %watchdog_browser_check_interval_in_sec%

if "%watchdog_remote_enabled%"=="0" goto BROWSER_WATCHDOG_LOOP

:WATCHDOG_LOOP
:: default when the server does not respond or curl fails
set "response=2"
set "watchdog_http_status=000"
if exist "%watchdog_response_file%" del "%watchdog_response_file%" /Q >nul 2>nul
if exist "%watchdog_http_status_file%" del "%watchdog_http_status_file%" /Q >nul 2>nul
:: -L follows redirects so a 301/302 "Redirect..." body is not mistaken for a command.
:: -o writes the final body; -w writes only the final HTTP status to stdout (captured below).
curl -k -L -s -o "%watchdog_response_file%" -w "%%{http_code}" "!watchdog_url!" > "%watchdog_http_status_file%" 2>nul
set "curl_errorlevel=!errorlevel!"
if not "!curl_errorlevel!"=="0" (
  call :LOG "Watchdog - ERROR: curl failed, errorlevel !curl_errorlevel!"
) else (
  if exist "%watchdog_http_status_file%" (
    for /f "usebackq delims=" %%s in ("%watchdog_http_status_file%") do set "watchdog_http_status=%%s"
  )
  call :LOG "Watchdog - HTTP status: !watchdog_http_status!"
  if exist "%watchdog_response_file%" (
    call :LOG "Watchdog - raw body:"
    type "%watchdog_response_file%" >> "%playr_log%"
    echo.>> "%playr_log%"
    for /f "usebackq delims=" %%d in ("%watchdog_response_file%") do set "response=%%d"
  ) else (
    call :LOG "Watchdog - WARNING: curl returned no response file"
  )
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
  call :LOG "Reboot command received from server"
  echo Rebooting the device in 30 seconds...
  shutdown /r /t 30
  exit /b 0
) else (
  call :LOG "Watchdog - processed server response: !watchdog_response! (from '!response!'), no reboot required"
)
call :RESTART_BROWSER_IF_NEEDED
call :REASSERT_PLAYR_BROWSER_TOPMOST
call :LOG "Continuing watchdog (last server response: !watchdog_response!, HTTP !watchdog_http_status!)"
:: Sleep until the next remote poll, but re-check the browser and re-assert the full-screen
:: window every browser-check interval so a Windows 11 taskbar pop-up is corrected within
:: seconds instead of only once per (much longer) remote poll interval.
set /a "watchdog_remaining=watchdog_remote_poll_interval_in_sec"
:WATCHDOG_REMOTE_WAIT
if not defined watchdog_remaining set "watchdog_remaining=0"
if !watchdog_remaining! leq 0 goto WATCHDOG_LOOP
if !watchdog_remaining! lss !watchdog_browser_check_interval_in_sec! (
  call :WAIT_SECONDS !watchdog_remaining!
  set "watchdog_remaining=0"
) else (
  call :WAIT_SECONDS !watchdog_browser_check_interval_in_sec!
  set /a "watchdog_remaining-=watchdog_browser_check_interval_in_sec"
)
call :RESTART_BROWSER_IF_NEEDED
call :REASSERT_PLAYR_BROWSER_TOPMOST
goto WATCHDOG_REMOTE_WAIT

:BROWSER_WATCHDOG_LOOP
call :RESTART_BROWSER_IF_NEEDED
call :REASSERT_PLAYR_BROWSER_TOPMOST
call :WAIT_SECONDS %watchdog_browser_check_interval_in_sec%
goto BROWSER_WATCHDOG_LOOP

goto :eof

:LOG
:: Append a timestamped line to %playr_log%.
:: Usage: call :LOG "WARNING: curl returned no response file"
:: The message is taken from %~1 (not a named %var%), so literal % characters in
:: values such as URL-encoded device ids are not re-paired against %playr_log%.
>>"%playr_log%" echo %date% %time% %~1
exit /b 0

:WAIT_SECONDS
:: Sleep %~1 seconds without relying on console stdin.
:: Do NOT use timeout.exe here: under start /min and Task Scheduler it often fails
:: immediately ("Input redirection is not supported"), which spins the watchdog and
:: respawns browsers about once per second. ping -n is reliable in those contexts.
:: "Missing operand" is avoided by validating that the argument is a positive integer
:: before any set /a or numeric IF.
set "playr_wait_secs=%~1"
if not defined playr_wait_secs set "playr_wait_secs=1"
echo !playr_wait_secs!| findstr /r "^[1-9][0-9]*$" >nul
if errorlevel 1 set "playr_wait_secs=1"
set /a "playr_ping_count=playr_wait_secs+1"
if !playr_ping_count! LSS 2 set "playr_ping_count=2"
ping -n !playr_ping_count! 127.0.0.1 >nul 2>nul
exit /b 0

:RESOLVE_POWERSHELL_EXE
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
exit /b 0

:RESOLVE_WMIC_EXE
set "wmic_exe="
if exist "%SystemRoot%\System32\wbem\WMIC.exe" set "wmic_exe=%SystemRoot%\System32\wbem\WMIC.exe"
if not defined wmic_exe (
  for /f "delims=" %%W in ('where wmic 2^>nul') do (
    if not defined wmic_exe set "wmic_exe=%%W"
  )
)
exit /b 0

:RESOLVE_DEVICE_ID_VIA_POWERSHELL
call :RESOLVE_POWERSHELL_EXE
if not defined powershell_exe exit /b 0
"%powershell_exe%" -NoProfile -Command "(Get-WmiObject Win32_ComputerSystemProduct).UUID" > "%TEMP%\playr_device_id.txt" 2>nul
if exist "%TEMP%\playr_device_id.txt" (
  for /f "usebackq delims=" %%u in ("%TEMP%\playr_device_id.txt") do set "device_id=%%u"
  del "%TEMP%\playr_device_id.txt" /Q >nul 2>nul
)
set "device_id=!device_id: =!"
exit /b 0

:ENCODE_DEVICE_ID_FOR_URL
set "device_id_encoded=%device_id%"
set "DEVICE_ID=%device_id%"
call :RESOLVE_POWERSHELL_EXE
:: Do NOT run PowerShell inside for /f `"%powershell_exe%" ...`: with more than two
:: quote chars on the line, cmd /c strips the outer quotes and the exe path ends up with
:: a trailing quote -> "The filename, directory name, or volume label syntax is incorrect".
:: Instead redirect PowerShell stdout to a temp file (CMD does the redirect = ANSI text)
:: and read it back.
if defined powershell_exe (
  "%powershell_exe%" -NoProfile -Command "[uri]::EscapeDataString($env:DEVICE_ID)" > "%TEMP%\playr_device_id_encoded.txt" 2>nul
  if exist "%TEMP%\playr_device_id_encoded.txt" (
    for /f "usebackq delims=" %%U in ("%TEMP%\playr_device_id_encoded.txt") do set "device_id_encoded=%%U"
    del "%TEMP%\playr_device_id_encoded.txt" /Q >nul 2>nul
    exit /b 0
  )
)
:: Fallback when PowerShell is unavailable: encode characters that break URL paths
set "device_id_encoded=%device_id%"
set "device_id_encoded=!device_id_encoded:;=%%3B!"
set "device_id_encoded=!device_id_encoded::=%%3A!"
set "device_id_encoded=!device_id_encoded: =%%20!"
exit /b 0

:PATCH_PLAYR_PROFILE_PREFERENCES
set "PLAYR_PROFILE=%playr_profile_dir%"
call :RESOLVE_POWERSHELL_EXE
if defined powershell_exe (
  call :LOG "Patching profile Preferences via PowerShell"
  "%powershell_exe%" -NoProfile -ExecutionPolicy Bypass -Command "$profileDir=$env:PLAYR_PROFILE; $p=Join-Path $profileDir 'Default\Preferences'; if(Test-Path $p){ try { $j=Get-Content -Raw $p | ConvertFrom-Json; if($null -eq $j.profile){ $j | Add-Member -MemberType NoteProperty -Name profile -Value ([pscustomobject]@{}) }; if($j.profile.PSObject.Properties.Name -contains 'exit_type'){ $j.profile.exit_type='Normal' } else { $j.profile | Add-Member -MemberType NoteProperty -Name exit_type -Value 'Normal' }; if($j.profile.PSObject.Properties.Name -contains 'exited_cleanly'){ $j.profile.exited_cleanly=$true } else { $j.profile | Add-Member -MemberType NoteProperty -Name exited_cleanly -Value $true }; $j | ConvertTo-Json -Depth 100 | Set-Content -Encoding UTF8 $p } catch { Rename-Item $p ($p + '.bad.' + (Get-Date -Format 'yyyyMMddHHmmss')) -Force } }" >nul 2>nul
  if not errorlevel 1 exit /b 0
  call :LOG "WARNING: PowerShell Preferences patch failed; trying cscript"
)
set "cscript_exe="
if exist "%SystemRoot%\System32\cscript.exe" set "cscript_exe=%SystemRoot%\System32\cscript.exe"
if not defined cscript_exe (
  for /f "delims=" %%C in ('where cscript 2^>nul') do (
    if not defined cscript_exe set "cscript_exe=%%C"
  )
)
if defined cscript_exe (
  call :LOG "Patching profile Preferences via cscript"
  call :WRITE_PLAYR_PATCH_PREFERENCES
  "%cscript_exe%" //nologo "%TEMP%\playr_patch_preferences.vbs" "%playr_profile_dir%" >nul 2>nul
  exit /b 0
)
call :LOG "WARNING: PowerShell and cscript unavailable; deleting Preferences file"
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

:PREPARE_PLAYR_PROFILE
:: Never touch the profile of a running browser: deleting Singleton* locks or rewriting
:: Preferences under a live Chrome/Edge disrupts it (and can look like a random shutdown).
:: Only clean locks / patch Preferences when the browser is confirmed NOT running.
call :IS_PLAYR_BROWSER_RUNNING
if "!playr_browser_running!"=="1" (
  call :LOG "Playr browser already running; skipping profile lock cleanup / Preferences patch"
  exit /b 0
)
call :LOG "Preparing Playr profile before launch"
:: Quote the path (%%~F strips quotes): %playr_profile_dir% lives under %LOCALAPPDATA%,
:: which contains the account name and may include spaces or other special characters.
for %%F in (
  "%playr_profile_dir%\SingletonLock"
  "%playr_profile_dir%\SingletonCookie"
  "%playr_profile_dir%\SingletonSocket"
) do (
  if exist "%%~F" del "%%~F" /Q >nul 2>nul
)
call :PATCH_PLAYR_PROFILE_PREFERENCES
exit /b 0

:LAUNCH_PLAYR_BROWSER
call :PREPARE_PLAYR_PROFILE
call :LOG "Launching browser"
start "" "%browser_executable%" %gpu_options% %persistency_options% %no_nagging_options% --user-data-dir="%playr_profile_dir%" --start-fullscreen --kiosk --app="!app_url!"
call :LOG "Browser launch requested"
:: Give Chrome time to create its process tree before the next "is it running?" check.
call :WAIT_SECONDS 5
exit /b 0

:RESTART_BROWSER_IF_NEEDED
call :IS_PLAYR_BROWSER_RUNNING
if "!playr_browser_running!"=="1" exit /b 0
call :LOG "WARNING: Playr browser (%browser_process_name% with profile %playr_profile_dir%) not running; restarting"
call :LAUNCH_PLAYR_BROWSER
exit /b 0

:REASSERT_PLAYR_BROWSER_TOPMOST
:: Windows 11's rewritten taskbar intermittently draws itself on top of full-screen
:: (kiosk / --app) windows even though the browser never actually left full screen.
:: Re-set the Playr browser window to TOPMOST (the same z-order band the taskbar uses,
:: re-inserting us above it) with SWP_NOMOVE^|SWP_NOSIZE^|SWP_NOACTIVATE (0x13) so we do
:: not move, resize or steal focus. Matching on the dedicated profile dir leaves any
:: unrelated browser windows alone. This is a backstop; the durable fix is a shell-less
:: kiosk (Shell Launcher). No-op when PowerShell is unavailable.
call :RESOLVE_POWERSHELL_EXE
if not defined powershell_exe exit /b 0
set "PLAYR_PROFILE_DIR=%playr_profile_dir%"
set "BROWSER_PROCESS=%browser_process_name%"
"%powershell_exe%" -NoProfile -Command "$ErrorActionPreference='SilentlyContinue'; $q=[char]34; $sig='[DllImport('+$q+'user32.dll'+$q+')] public static extern bool SetWindowPos(IntPtr h,IntPtr a,int x,int y,int cx,int cy,uint f);'; $t=Add-Type -MemberDefinition $sig -Name PlayrWin -Namespace Playr -PassThru; $p=$env:PLAYR_PROFILE_DIR; $n=$env:BROWSER_PROCESS; Get-WmiObject Win32_Process -Filter ('Name='''+$n+'''') | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($p) } | ForEach-Object { $pr=Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue; if($pr -and $pr.MainWindowHandle -ne 0){ [Playr.PlayrWin]::SetWindowPos($pr.MainWindowHandle,([IntPtr]-1),0,0,0,0,0x13) | Out-Null } }" >nul 2>nul
exit /b 0

:IS_PLAYR_BROWSER_RUNNING
set "playr_browser_running=0"
set "PLAYR_PROFILE_DIR=%playr_profile_dir%"
set "BROWSER_PROCESS=%browser_process_name%"
call :RESOLVE_POWERSHELL_EXE
:: Prefer a profile-specific match (command line contains --user-data-dir / Playr profile).
:: On many locked-down / non-elevated Windows 11 sessions Win32_Process.CommandLine is
:: empty, so PowerShell correctly finds chrome.exe but cannot see the profile path and
:: would report "not running". Do NOT exit in that case - fall through to wmic/tasklist.
:: Otherwise the watchdog deletes Singleton* locks and starts another browser every cycle.
if defined powershell_exe (
  "%powershell_exe%" -NoProfile -Command "$p=$env:PLAYR_PROFILE_DIR; $n=$env:BROWSER_PROCESS; $f=$false; Get-CimInstance Win32_Process -Filter ('Name='''+$n+'''') -ErrorAction SilentlyContinue | ForEach-Object { if($_.CommandLine -and $_.CommandLine.IndexOf($p,[StringComparison]::OrdinalIgnoreCase) -ge 0){ $f=$true } }; if($f){exit 0}else{exit 1}" >nul 2>nul
  set "playr_ps_detect_errorlevel=!errorlevel!"
  if "!playr_ps_detect_errorlevel!"=="0" (
    set "playr_browser_running=1"
    exit /b 0
  )
)
call :RESOLVE_WMIC_EXE
if defined wmic_exe (
  call :LOG "Checking browser status with wmic"
  "%wmic_exe%" process where "name='%browser_process_name%'" get CommandLine 2>nul | findstr /I /C:"%playr_profile_dir%" >nul
  if not errorlevel 1 (
    set "playr_browser_running=1"
    exit /b 0
  )
)
:: Last resort: process name only. On a dedicated signage PC this is enough to stop
:: endless respawns when command-line inspection is blocked.
call :LOG "Checking browser status with tasklist"
tasklist /FI "IMAGENAME eq %browser_process_name%" 2>nul | find /I "%browser_process_name%" >nul
if not errorlevel 1 set "playr_browser_running=1"
exit /b 0
