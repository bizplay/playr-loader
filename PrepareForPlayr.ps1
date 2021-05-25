###############################################################################
###############################################################################
###
### LICENSE
###
### This batch file is provided to show digital signage content from playr.biz
### To read more on the purpose of this file and how to use it
### see the accompanying README.md file or
### contact your digital signage provider.
###
### This file is licensed under the MIT license.
###
### THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
### EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
### OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
### NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
### HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
### WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
### FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
### OTHER DEALINGS IN THE SOFTWARE.
###
###############################################################################
###############################################################################

# Steps to prepare for digital signage playback
# 1 Update drivers
# 3 Disable auto update (is update in background possible?)
# 4 Disable energy save mode
# 2 Install Google Chrome  (use Chrome or Edge automatically)
# 5 Auto start Chrome
# 6 Auto player startup???
# 7 Auto player shutdown ???
# 8 Disable user login ???

###############################################################################
#
# Update third party drivers
#
# NOTE: Make sure the "Windows update" service is running
#
# https://superuser.com/a/1244097
# more elaborate update scripts: https://github.com/joeypiccola/PSWindowsUpdate
# detailed information: https://docs.microsoft.com/en-us/archive/blogs/jamesone/managing-windows-update-with-powershell
#
###############################################################################
# add "Microsoft Update" as additional Update-Source.
#$UpdateSvc = New-Object -ComObject Microsoft.Update.ServiceManager
#$UpdateSvc.AddService2("7971f918-a847-4430-9279-4a52d1efe18d",7,"")
# overview of all registerred sources
#(New-Object -ComObject Microsoft.Update.ServiceManager).Services
# clean up
# $updateSvc.Services | ? { $_.IsDefaultAUService -eq $false -and $_.ServiceID -eq "7971f918-a847-4430-9279-4a52d1efe18d" } | % { $UpdateSvc.RemoveService($_.ServiceID) }

#search and list all missing Drivers
$Session = New-Object -ComObject Microsoft.Update.Session
$Searcher = $Session.CreateUpdateSearcher()

$Searcher.ServiceID = '7971f918-a847-4430-9279-4a52d1efe18d'
$Searcher.SearchScope =  1 # MachineOnly
$Searcher.ServerSelection = 3 # Third Party
# $Searcher | GetMember # get information on Searcher
# $Searcher.getType()

$Criteria = "IsInstalled=0 and Type='Driver'"
Write-Host "Searching Driver Updates..."
$SearchResult = $Searcher.Search($Criteria)
$Updates = $SearchResult.Updates

#Show available Drivers
if(-not ([string]::IsNullOrEmpty($Updates))) {
    Write-Host "=> Updates found:" -Fore Green
    $Updates | select Title, DriverModel, DriverVerDate, Driverclass, DriverManufacturer | fl
} else {
    Write-Host "=> No third party driver updates found" -Fore Green
}


#Download the Drivers from Microsoft
$UpdatesToDownload = New-Object -Com Microsoft.Update.UpdateColl
$updates | % { $UpdatesToDownload.Add($_) | out-null }
if(-not ([string]::IsNullOrEmpty($UpdatesToDownload))) {
    Write-Host "Downloading Drivers"  -Fore Green
    $UpdatesToDownload | select Title | fl
    $UpdateSession = New-Object -Com Microsoft.Update.Session
    $Downloader = $UpdateSession.CreateUpdateDownloader()
    $Downloader.Updates = $UpdatesToDownload
    Write-Host "=> Start Download"  -Fore Green
    $Downloader.Download()

    #Check if the Drivers are all downloaded and trigger the Installation
    $UpdatesToInstall = New-Object -Com Microsoft.Update.UpdateColl
    $updates | % { if($_.IsDownloaded) { $UpdatesToInstall.Add($_) | out-null } }

    if ($null -ne $UpdatesToInstall) {
        Write-Host "=> Installing Drivers..."  -Fore Green
        $Installer = $UpdateSession.CreateUpdateInstaller()
        $Installer.Updates = $UpdatesToInstall
        $InstallationResult = $Installer.Install()
        if($InstallationResult.RebootRequired) { Write-Host "Drivers have been installed. Reboot required! please reboot after this script has finished" -Fore Red
        } else { Write-Host "=> Drivers have been installed." -Fore Green }
    } else { Write-Host "=> No drivers were installed" -Fore Red }
} else { Write-Host "=> No third party drivers to update" -Fore Green }


###############################################################################
#
# Set power plan to "High performance"
#
###############################################################################
Write-Host "Making sure the Power Plan is set for best performance:"
# fill a hashtable with power scheme guids and alias names:
# Name                                   Value
# -----                                  -----
# 381b4222-f694-41f0-9685-ff5bb260df2e   SCHEME_BALANCED  # --> Balanced
# 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c   SCHEME_MIN       # --> High performance
# a1841308-3541-4fab-bc81-f71556f20b4a   SCHEME_MAX       # --> Power saver

$powerConstants = @{}
PowerCfg.exe -ALIASES | Where-Object { $_ -match 'SCHEME_' } | ForEach-Object {
    $guid,$alias = ($_ -split '\s+', 2).Trim()
    $powerConstants[$guid] = $alias
}

# get a list of power schemes
$powerSchemes = PowerCfg.exe -LIST | Where-Object { $_ -match '^Power Scheme' } | ForEach-Object {
    $guid = $_ -replace '.*GUID:\s*([-a-f0-9]+).*', '$1'
    [PsCustomObject]@{
        Name     = $_.Trim("* ") -replace '.*\(([^)]+)\)$', '$1'          # LOCALIZED !
        Alias    = $powerConstants[$guid]
        Guid     = $guid
        IsActive = $_ -match '\*$'
    }
}

# set a variable for the desired power scheme (in this case High performance)
$desiredScheme = $powerSchemes | Where-Object { $_.Alias -eq 'SCHEME_MIN' }

# get the currently active scheme
$PowerSettingsorg = $powerSchemes | Where-Object { $_.IsActive }

if ($PowerSettingsorg.Alias -eq $desiredScheme.Alias) {
    # or by guid:   if ($PowerSettingsorg.Guid -eq $desiredScheme.Guid)
    # or localized: if ($PowerSettingsorg.Name -eq $desiredScheme.Name)
    # or:           if ($desiredScheme.IsActive)
    Write-Host "=> Power Plan Settings are correct: $($PowerSettingsorg.Name)"  -Fore Green
}
else {
    # set powersettings to High Performance
    Powercfg.exe -SETACTIVE $desiredScheme.Alias  # you can also set this using the $desiredScheme.Guid
    # test if the setting has changed
    $currentPowerGuid = (Powercfg.exe -GETACTIVESCHEME) -replace '.*GUID:\s*([-a-f0-9]+).*', '$1'
    if ($currentPowerGuid -eq $desiredScheme.Guid) {
        Write-Host "=> Power plan Settings have changed to $($desiredScheme.Name)!" -Fore Green
    }
    else {
        # do not exit the script here
        # Throw "Power plan Settings did not change to $($desiredScheme.Name)!"
        Write-Host "=> Power plan Settings did not change to $($desiredScheme.Name)!" -Fore Red
    }
}


###############################################################################
#
# Download and install Google Chrome
#
# https://dl.google.com/tag/s/installdataindex=empty/chrome/install/ChromeStandaloneSetup64.exe
# alternatives
# https://www.google.com/intl/en/chrome/?standalone=1
# https://www.google.com/intl/en/chrome/browser/desktop/index.html?standalone=1
#
###############################################################################
Write-Host "Making sure Google Chrome is installed:"
$source = 'https://dl.google.com/tag/s/installdataindex=empty/chrome/install/ChromeStandaloneSetup64.exe'
$destination = "$env:USERPROFILE\Downloads\ChromeStandaloneSetup64.exe"
# test if Chrome is present
$chromeExecutables = @(
    "$Env:PROGRAMFILES\Google\Chrome\Application\chrome.exe"
    "${Env:PROGRAMFILES(x86)}\Google\Chrome\Application\chrome.exe"
    "$Env:USERPROFILE\AppData\Local\Google\Chrome\Application\chrome.exe"
)

if (("" -ne $env:PROGRAMFILES) -and ("" -ne $env:USERPROFILE) -and
    (-not (Test-Path -Path $chromeExecutables[0] -PathType Leaf)) -and
    (-not (Test-Path -Path $chromeExecutables[1] -PathType Leaf)) -and
    (-not (Test-Path -Path $chromeExecutables[2] -PathType Leaf))
   ) {
    # chrome.exe is not present in the normal locations where it would be present of it had been installed
    try {
        Write-Host "Google Chrome not yet installed. Downloading install file..." -Fore Yellow
        # Invoke-WebRequest seems to rsult in $null
        $result = Invoke-WebRequest -Uri $source -OutFile $destination
        if ($result -eq 0) { 
            Write-Host "=> Download of Google Chrome installer was successful" -Fore Green
        } else {
            Write-Host "=> Download of Google Chrome installer was not successful!" -Fore Red
        }

        if (Test-Path -Path $destination -PathType Leaf) {
            Write-Host "=> Start installation..." -Fore Green
            #$newProc=([WMICLASS]"\\$_\root\cimv2:win32_Process").Create("$destination /S")
            Start-Process -FilePath $destination

            #If ($newProc.ReturnValue -eq 0) {
            if ($LASTEXITCODE -eq 0) {
                # Write-Host "$_ $newProc.ProcessId" -Fore Green
                Write-Host "=> Google Chrome was successfully installed" -Fore Green
            } else {
                # write-host "$_ Process create failed with $newProc.ReturnValue" -Fore Red
                write-host "Google Chrome install failed with $LASTEXITCODE" -Fore Red
            }
        } else {
            # Throw "Google Chrome installer application could not be downloaded!"
            Write-Host "=> Google Chrome installer application could not be downloaded!" -Fore Red
        }
    }
    catch {
        Throw $_.Exception.Message
    }
} else {
    # the file already exists, show the message and do nothing.
    Write-Host "=> Google Chrome is already installed." -Fore Green
}

###############################################################################
#
# Set Chrome cookie policy
#
###############################################################################
Write-Host "Setting Google Chrome cookie policy:"
if (-Not (Test-Path "HKLM:\Software\Policies\Google")) {
    New-Item -Path "HKLM:\Software\Policies" -Name "Google"
}
if (-Not (Test-Path "HKLM:\Software\Policies\Google\Chrome")) {
    New-Item -Path "HKLM:\Software\Policies\Google" -Name "Chrome"
}
if ((Get-Item -Path "HKLM:\Software\Policies\Google\Chrome\").GetValue("LegacySameSiteCookieBehaviorEnabled") -eq $null) {
    New-ItemProperty -Path "HKLM:\Software\Policies\Google\Chrome" -Name "LegacySameSiteCookieBehaviorEnabled" -Value 0x00000001 -PropertyType Dword
    Write-Host "=> Policy was set correctly" -Fore Green
} elseif ((Get-Item -Path "HKLM:\Software\Policies\Google\Chrome\").GetValue("LegacySameSiteCookieBehaviorEnabled") -ne 1) {
    Set-ItemProperty -Path "HKLM:\Software\Policies\Google\Chrome" -Name "LegacySameSiteCookieBehaviorEnabled" -Value 0x00000001
    Write-Host "=> Policy was set correctly" -Fore Green
} else {
    Write-Host "=> Policy is already set correctly" -Fore Green
}

###############################################################################
#
# Enable setting no password login
#
###############################################################################
Write-Host "Enable setting passwordless login:"
if (-Not (Test-Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\PasswordLess")) {
    New-Item -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion" -Name "PasswordLess"
}
if (-Not (Test-Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device")) {
    New-Item -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\PasswordLess" -Name "Device"
}
if ((Get-Item -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device\").GetValue("DevicePasswordLessBuildVersion") -eq $null) {
    New-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" -Name "DevicePasswordLessBuildVersion" -Value 0x00000000 -PropertyType Dword
    Write-Host "=> Setting passwordless login is now possible" -Fore Green
} elseif ((Get-Item -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device\").GetValue("DevicePasswordLessBuildVersion") -ne 0) {
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" -Name "DevicePasswordLessBuildVersion" -Value 0x00000000
    Write-Host "=> Setting passwordless login is now possible" -Fore Green
} else {
    Write-Host "=> Setting passwordless login is already possible" -Fore Green
}