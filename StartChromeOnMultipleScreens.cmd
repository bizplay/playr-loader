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

::
:: make sure that the path to the playr_loader.html file is correct in your situation
:: %USERPROFILE% points to your personal profile directory, that usually can be found
:: at C:\Users\<your user name>
::
set playr_loader_file=%USERPROFILE%/Desktop/playr_loader.html
::
:: change the urls below to point at your channels
::
set channel1=http://playr.biz/9583/48
set channel2=http://playr.biz/9583/44
set channel3=http://playr.biz/9583/51
::
:: change the paths below to point at the different chrome.exe's that are installed on your computer
:: you can find the path to the chrome.exe by right clicking the (desktop) icon  of Chrome/Chrome Canary/Chromium, choosing properties
:: and looking in the Target field 
::
set google_chrome_path="C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
set google_chrome_canary_path="%USERPROFILE%\AppData\Local\Google\Chrome SxS\Application\chrome.exe"
set chromium_path="C:\Program Files (x86)\Chromium\chrome.exe"
::
:: The window positions specified below will work when you use three 1080p screens (1920x1080)
:: If you use screens with a different resolution you may need to change the values below. 
::
screen_position1=50,20
screen_position2=2000,20
screen_position3=4000,20
::	
:: The code below should work as is and should not require any changes
::
del "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\Default" /S /Q
del "%USERPROFILE%\AppData\Local\Google\Chrome SxS\User Data\Default" /S /Q
start /min cmd /c "%google_chrome_path% --chrome-frame --disable-first-run-ui --no-default-browser-check --disable-translate --window-position=%screen_position1% --kiosk file:///%playr_loader_file%?channel=%channel%"
start /min cmd /c "%chromium_path% --chrome-frame --disable-first-run-ui --no-default-browser-check --disable-translate --window-position=%screen_position2% --kiosk file:///%playr_loader_file%?channel=%channe2%"
start /min cmd /c "%google_chrome_canary_path% --chrome-frame --disable-first-run-ui --no-default-browser-check --disable-translate --window-position=%screen_position3% --kiosk file:///%playr_loader_file%?channel=%channe3%"