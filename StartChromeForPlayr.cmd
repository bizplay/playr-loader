@echo off
set channel=http://playr.biz/xxxx/yyyy

set playr_loader_file=%USERPROFILE%/Desktop/playr_loader.html

del "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\Default" /S /Q
"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" --disable-translate --kiosk "file:///%playr_loader_file%?channel=%channel%"  
"%USERPROFILE%\AppData\Local\Google\Chrome\Application\chrome.exe" --disable-translate --kiosk "file:///%playr_loader_file%?channel=%channel%"  
