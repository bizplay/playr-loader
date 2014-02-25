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
set channel=http://playr.biz/xxxx/yyyy

::	
:: The code below should work as is and should not require any changes
::
del "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\Default" /S /Q
"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" --disable-translate --kiosk "file:///%playr_loader_file%?channel=%channel%"  
"%USERPROFILE%\AppData\Local\Google\Chrome\Application\chrome.exe" --disable-translate --kiosk "file:///%playr_loader_file%?channel=%channel%"  
