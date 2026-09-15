###############################################################################
###############################################################################
###
### LICENSE
###
### This script is provided to show digital signage content from playr.biz
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

# Harden a Windows 11 signage player against the taskbar intermittently appearing
# on top of the full-screen (kiosk / --app) browser window.
#
# Windows 11 rewrote the taskbar (a XAML/UWP surface hosted in explorer.exe). That
# rewrite introduced a regression where shell components can re-assert the taskbar's
# z-order over a full-screen window. This script removes the most common triggers and
# makes the shell less able to steal focus:
#   * disables Widgets / News and interests (frequent background trigger)
#   * disables notifications / toasts (a toast reveals the taskbar over the app)
#   * enforces the "don't let background apps steal focus" guard (ForegroundLockTimeout)
#   * enables taskbar auto-hide as a last line of defence
#
# NOTE: this is a mitigation, not a cure. The only fully reliable fix for signage is a
# shell-less kiosk (Windows 11 Enterprise/IoT Enterprise + Shell Launcher) so that
# explorer.exe / the taskbar never runs at all.
#
# HKLM changes require running elevated (as Administrator). HKCU changes apply to the
# account that runs this script - run it as the signage playback account.
# The keys are harmless on Windows 10 (ignored where not applicable).

function Set-PlayrRegistryValue {
    param(
        [Parameter(Mandatory = $true)] [string] $Path,
        [Parameter(Mandatory = $true)] [string] $Name,
        [Parameter(Mandatory = $true)] $Value,
        [ValidateSet('DWord', 'String')] [string] $Type = 'DWord'
    )
    try {
        if (-not (Test-Path -Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        Write-Host "=> Set $Path\$Name = $Value" -Fore Green
        return $true
    }
    catch {
        Write-Host "=> FAILED to set $Path\$Name : $($_.Exception.Message)" -Fore Red
        return $false
    }
}

Write-Host "Hardening the Windows 11 taskbar so it stays hidden behind full-screen playback:"

###############################################################################
#
# 1. Disable Windows 11 Widgets / News and interests
#    The widgets board (weather/news on the taskbar) updates in the background and is
#    a common cause of the taskbar re-appearing over a full-screen app.
#
###############################################################################
# Policy-level disable of the whole widgets experience (strongest, survives updates)
Set-PlayrRegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0
# Remove the Widgets button from the taskbar for the current user
Set-PlayrRegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0
# Legacy "News and interests" (Windows 10 / early Windows 11)
Set-PlayrRegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" -Name "EnableFeeds" -Value 0

###############################################################################
#
# 2. Disable notifications / toasts
#    A toast (Windows Update, security, app prompts, etc.) reveals the taskbar and the
#    notification/flyout surface on top of the playback window.
#
###############################################################################
Set-PlayrRegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled" -Value 0
Set-PlayrRegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Value 0
Set-PlayrRegistryValue -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "DisableNotificationCenter" -Value 1

###############################################################################
#
# 3. Foreground-steal damper
#    ForegroundLockTimeout controls how long Windows blocks a background app from
#    forcing itself to the foreground after the last user input. On an unattended
#    signage player there is no user input, so a value of 0 (set by some "tweak"
#    tools) lets ANY background process (notifications, device-arrival prompts, shell
#    extensions) pull focus and drag the taskbar up. Restore the Windows default of
#    200000 ms so the guard is active.
#    (ForegroundFlashCount is intentionally NOT changed: a value of 0 causes a taskbar
#    button to flash continuously, which is the opposite of what we want.)
#
###############################################################################
Set-PlayrRegistryValue -Path "HKCU:\Control Panel\Desktop" -Name "ForegroundLockTimeout" -Value 200000

###############################################################################
#
# 4. Enable taskbar auto-hide (last line of defence)
#    Even if something does reveal the taskbar, auto-hide lets it slide away again
#    instead of staying on screen. Stored as a bit in the StuckRects3 binary blob:
#    byte index 8 -> 0x03 = auto-hide on, 0x02 = auto-hide off.
#
###############################################################################
try {
    $stuck = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
    if (Test-Path $stuck) {
        $settings = (Get-ItemProperty -Path $stuck -Name Settings -ErrorAction Stop).Settings
        if ($settings -and $settings.Length -gt 8) {
            $settings[8] = 0x03
            Set-ItemProperty -Path $stuck -Name Settings -Value $settings
            Write-Host "=> Taskbar auto-hide enabled" -Fore Green
        }
        else {
            Write-Host "=> Could not read StuckRects3 layout; enable taskbar auto-hide manually" -Fore Yellow
        }
    }
    else {
        Write-Host "=> Taskbar layout not initialised yet; auto-hide will need to be set after first sign-in" -Fore Yellow
    }
}
catch {
    Write-Host "=> Could not toggle taskbar auto-hide: $($_.Exception.Message)" -Fore Red
}

###############################################################################
#
# 5. Apply Explorer-driven changes (Widgets button, auto-hide) by restarting Explorer.
#    Policy/notification changes fully take effect after the next sign-in or reboot.
#
###############################################################################
try {
    Write-Host "Restarting Explorer to apply taskbar changes..."
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer.exe
    }
    Write-Host "=> Explorer restarted (sign out / reboot to fully apply policy changes)" -Fore Green
}
catch {
    Write-Host "=> Please sign out/in (or reboot) to apply the taskbar changes" -Fore Yellow
}
