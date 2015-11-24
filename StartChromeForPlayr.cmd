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

:: change and use the url below if you want to play a specific channel that cannot be 
:: changed from your dashboard
:: Note: add /en, /nl or other language indication before /xxxx to enforce the 
:: use of the correct locale 
::
set channel=http://playr.biz/xxxx/yyyy

:: use the url below if you want be able to set the channel to play on your dashboard.
:: Note: using this setting requires a one time registration of the playback device
:: using the dashboard (under Settings/Players) 
::
:: set channel=http://play.playr.biz

:: If you do not use the http://play.plyr.biz URL but a specific channel URL
:: you can uncomment the line below to prevent the 
:: "Google Chrome didn't shut down correclty"
:: warning when restarting after a crash of Windows (power outage)
::
:: del "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\Default\Preferences" /Q

:: The code below should work as is and should not require any changes
::
setlocal enabledelayedexpansion
set replace=%%20
set playr_loader_file_normalized=%playr_loader_file: =!replace!%
if exist "C:\Program Files\Google\Chrome\Application\chrome.exe" (
  "C:\Program Files\Google\Chrome\Application\chrome.exe" --no-first-run --no-default-browser-check --disable-translate --kiosk "file:///%playr_loader_file_normalized%?channel=%channel%"
) else (
  "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" --no-first-run --no-default-browser-check --disable-translate --kiosk "file:///%playr_loader_file_normalized%?channel=%channel%"
)

:: Older version of Chrome were installed in the AppData folder of a specific user, 
:: if the above code does not work you may consider using the line below instead of 
:: the lines above that assume Chrome is installed in the Program Files directory
::
::"%USERPROFILE%\AppData\Local\Google\Chrome\Application\chrome.exe" --disable-first-run-ui --no-default-browser-check --disable-translate --kiosk "file:///%playr_loader_file_normalized%?channel=%channel%"
