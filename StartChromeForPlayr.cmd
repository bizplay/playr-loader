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
set no_nagging_options=--disable-translate --no-first-run --no-default-browser-check --disable-infobars --autoplay-policy=no-user-gesture-required --no-user-gesture-required --disable-session-crashed-bubble

:: Prevent the
:: "Google Chrome didn't shut down correctly"
:: warning when restarting after a crash of Windows, power outage or
:: other non standard way to end Windows.
:: Choose one of the following options. The first only deletes one file
:: the second option deletes all browser data such as cached videos. The
:: second option should only be used on devices that have little disk space
:: to implement the second option replace the three lines inside the following
:: if clause with this
:: del "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\Default\" /S /Q
if exist "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\Default" (
  if exist "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\Default\Preferences" (
    del "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\Default\Preferences" /Q
  )
)
:: when using Chromium use one of the two options, see above
:: del "%USERPROFILE%\AppData\Local\Chromium\User Data\Default\" /S /Q
if exist "%USERPROFILE%\AppData\Local\Chromium\User Data\Default" (
  if exist "%USERPROFILE%\AppData\Local\Chromium\User Data\Default\Preferences" (
    del "%USERPROFILE%\AppData\Local\Chromium\User Data\Default\Preferences" /Q
  )
)
:: when using Microsoft Edge use one of the two options, see above
:: del "%USERPROFILE%\AppData\Local\Chromium\User Data\Default\" /S /Q
if exist "%USERPROFILE%\AppData\Local\Microsoft\Edge\User Data\Default" (
  if exist "%USERPROFILE%\AppData\Local\Microsoft\Edge\User Data\Default\Preferences" (
    del "%USERPROFILE%\AppData\Local\Microsoft\Edge\User Data\Default\Preferences" /Q
  )
)

::
:: The code below should work as is and should not require any changes
::
setlocal enabledelayedexpansion
set replace=%%20
set playr_loader_file_normalized=%playr_loader_file: =!replace!%

::
:: the code below should work after a 'normal' installation of either Google Chrome or Chromium
::
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" (
  set browser_executable="%ProgramFiles%\Google\Chrome\Application\chrome.exe"
) else (
  if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" (
    set browser_executable="%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
  ) else (
    if exist "%USERPROFILE%\AppData\Local\Google\Chrome\Application\chrome.exe" (
      set browser_executable="%USERPROFILE%\AppData\Local\Google\Chrome\Application\chrome.exe"
    ) else (
      if exist "%ProgramFiles%\Chromium\chrome.exe" (
        set browser_executable="%ProgramFiles%\Chromium\chrome.exe"
      ) else (
        if exist "%ProgramFiles(x86)%\Chromium\chrome.exe" (
          set browser_executable="%ProgramFiles(x86)%\Chromium\chrome.exe"
        ) else (
          if exist "%USERPROFILE%\AppData\Local\Chromium\Application\chrome.exe" (
            set browser_executable="%USERPROFILE%\AppData\Local\Chromium\Application\chrome.exe"
          ) else (
            REM in case Chrome or Chromium cannot be found => default to Microsoft Edge
            REM as up to date versions of that are also Blink (Chromium/Chrome redering engine) based
            if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" (
              set browser_executable="%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
            ) else (
              if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" (
                set browser_executable="%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
              ) else (
                REM in case even Microsoft Edge cannot be found => default to Microsoft Internet Explorer
                REM this will certainly not give the best results, command line parameters might give errors
                if exist "%ProgramFiles%\Internet Explorer\iexplore.exe" (
                  set browser_executable="%ProgramFiles%\Internet Explorer\iexplore.exe"
                ) else (
                  if exist "%ProgramFiles(x86)%\Internet Explorer\iexplore.exe" (
                    set browser_executable="%ProgramFiles(x86)%\Internet Explorer\iexplore.exe"
                  ) else (
                    REM if all else fails
                    set browser_executable="iexplore.exe"
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)

:: start chrome from a minimized cmd.exe using the options that were set up above
start /min cmd /c "%browser_executable% %gpu_options% %persistency_options% %no_nagging_options% --kiosk file:///%playr_loader_file_normalized%?channel=%channel%"
