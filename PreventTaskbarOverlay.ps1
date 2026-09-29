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

# Are we running elevated? Machine-wide (HKLM) writes require Administrator; per-user
# (HKCU) writes do not. Detect this once so HKLM changes can be skipped cleanly instead
# of throwing an UnauthorizedAccessException.
$script:IsElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Optional fallback: when an HKLM write is refused even though we are elevated (cause #2 -
# a key whose ACL is locked to SYSTEM/TrustedInstaller), attempt to take ownership of the
# key, grant Administrators FullControl and retry the write once. Set to $false to disable.
$script:AttemptTakeOwnership = $true

# Holds the last error record from Invoke-PlayrRegistryWrite so the caller can inspect it.
$script:LastRegistryError = $null
$script:PrivilegeHelperAdded = $false

# Enable a named privilege (e.g. SeTakeOwnershipPrivilege) on the current process token.
# Taking ownership of an ACL-locked registry key needs SeTakeOwnershipPrivilege (and
# SeRestorePrivilege to rewrite the owner); both are held by admins but must be enabled.
function Enable-PlayrPrivilege {
    param([Parameter(Mandatory = $true)] [string] $Privilege)
    if (-not $script:PrivilegeHelperAdded) {
        $definition = @'
using System;
using System.Runtime.InteropServices;
public class PlayrTokenPriv {
    [DllImport("advapi32.dll", SetLastError=true)]
    static extern bool OpenProcessToken(IntPtr h, int acc, out IntPtr phtok);
    [DllImport("advapi32.dll", SetLastError=true)]
    static extern bool LookupPrivilegeValue(string host, string name, out long pluid);
    [DllImport("advapi32.dll", SetLastError=true)]
    static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall, ref TOKPRIV1LUID newst, int len, IntPtr prev, IntPtr relen);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern IntPtr GetCurrentProcess();
    [StructLayout(LayoutKind.Sequential, Pack=1)]
    struct TOKPRIV1LUID { public int Count; public long Luid; public int Attr; }
    const int SE_PRIVILEGE_ENABLED = 0x00000002;
    const int TOKEN_QUERY = 0x00000008;
    const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
    public static bool EnablePrivilege(string privilege) {
        IntPtr htok;
        if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, out htok)) return false;
        TOKPRIV1LUID tp;
        tp.Count = 1; tp.Attr = SE_PRIVILEGE_ENABLED; tp.Luid = 0;
        if (!LookupPrivilegeValue(null, privilege, out tp.Luid)) return false;
        return AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
    }
}
'@
        Add-Type -TypeDefinition $definition -ErrorAction Stop
        $script:PrivilegeHelperAdded = $true
    }
    return [PlayrTokenPriv]::EnablePrivilege($Privilege)
}

# Walk up from $Path (HKLM:\...) and return the deepest key that actually exists.
function Get-PlayrNearestExistingHklmKey {
    param([Parameter(Mandatory = $true)] [string] $Path)
    $p = $Path
    while ($p -and ($p -match '\\')) {
        if (Test-Path -Path $p) { return $p }
        $p = Split-Path -Path $p -Parent
    }
    return $null
}

# The actual registry write. Stores any error in $script:LastRegistryError and returns
# $true/$false instead of throwing, so callers can retry.
function Invoke-PlayrRegistryWrite {
    param(
        [string] $Path, [string] $Name, $Value, [string] $Type
    )
    $script:LastRegistryError = $null
    try {
        if (-not (Test-Path -Path $Path)) {
            # -ErrorAction Stop turns a non-terminating access-denied error into a
            # terminating one so the catch block actually handles it.
            New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
        }
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        $script:LastRegistryError = $_
        return $false
    }
}

# Explain WHY an HKLM write failed so support can tell cause #1 (not elevated) apart from
# cause #2 (key ACL-locked to SYSTEM/TrustedInstaller) and cause #3 (managed by MDM/GPO).
function Write-PlayrRegistryFailureDiagnosis {
    param([string] $Path, $ErrorRecord)
    $msg = if ($ErrorRecord) { $ErrorRecord.Exception.Message } else { 'unknown error' }
    Write-Host "=> FAILED to write $Path" -Fore Red
    Write-Host "   Error: $msg" -Fore Red

    if (-not $script:IsElevated) {
        Write-Host "   Diagnosis: CAUSE #1 - this PowerShell session is NOT elevated." -Fore Yellow
        Write-Host "   'Run with PowerShell' from Explorer does NOT elevate; use 'Run as administrator'" -Fore Yellow
        Write-Host "   (or let PrepareForPlayr.ps1 auto-elevate)." -Fore Yellow
        return
    }

    Write-Host "   Diagnosis: the session IS elevated (Administrator), so this is NOT cause #1." -Fore Yellow
    Write-Host "   => That means cause #2 (key ACL locked to SYSTEM/TrustedInstaller) or" -Fore Yellow
    Write-Host "      cause #3 (the setting is managed by MDM / Group Policy)." -Fore Yellow

    # Cause #2 evidence: owner and whether Administrators can write on the nearest key.
    $nearest = Get-PlayrNearestExistingHklmKey -Path $Path
    if ($nearest) {
        try {
            $acl = Get-Acl -Path $nearest -ErrorAction Stop
            Write-Host "   Nearest existing key: $nearest" -Fore Yellow
            Write-Host "   Owner: $($acl.Owner)" -Fore Yellow
            $adminsCanWrite = $false
            foreach ($ace in $acl.Access) {
                if (($ace.AccessControlType -eq 'Allow') -and
                    ("$($ace.IdentityReference)" -match 'Administrators|S-1-5-32-544') -and
                    ("$($ace.RegistryRights)" -match 'FullControl|SetValue|CreateSubKey|WriteKey')) {
                    $adminsCanWrite = $true
                }
            }
            if ($adminsCanWrite) {
                Write-Host "   Administrators DO have write rights here -> cause #2 unlikely; cause #3 (managed) more likely." -Fore Yellow
            }
            else {
                Write-Host "   Administrators do NOT have write rights here -> consistent with cause #2 (ACL-locked key)." -Fore Yellow
            }
        }
        catch {
            Write-Host "   Could not read ACL of ${nearest}: $($_.Exception.Message)" -Fore Yellow
        }
    }

    # Cause #3 evidence: is the device centrally managed?
    $managedHint = @()
    try {
        if ((Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).PartOfDomain) {
            $managedHint += 'domain-joined (Group Policy may manage this)'
        }
    }
    catch { }
    try {
        if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Enrollments') {
            $enrolled = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue |
                ForEach-Object { Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue } |
                Where-Object { $_.UPN -or ($_.EnrollmentState -eq 1) }
            if ($enrolled) { $managedHint += 'MDM-enrolled (Intune/CSP may manage this)' }
        }
    }
    catch { }
    if ($managedHint.Count -gt 0) {
        Write-Host "   This device appears $([string]::Join(' and ', $managedHint))." -Fore Yellow
        Write-Host "   If so, set the Widgets policy via Group Policy/Intune instead - local writes get reverted." -Fore Yellow
    }
}

# Take ownership of the nearest existing ancestor of $Path and grant Administrators
# FullControl (inherited), so a subsequent write/subkey-create can succeed. Returns
# $true on success. This is the cause #2 remedy.
function Repair-PlayrHklmKeyPermissions {
    param([Parameter(Mandatory = $true)] [string] $Path)
    $target = Get-PlayrNearestExistingHklmKey -Path $Path
    if (-not $target) { return $false }
    $subKey = $target -replace '^HKLM:\\', ''
    try {
        Enable-PlayrPrivilege 'SeTakeOwnershipPrivilege' | Out-Null
        Enable-PlayrPrivilege 'SeRestorePrivilege' | Out-Null
        $admins = New-Object System.Security.Principal.SecurityIdentifier(
            [System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)
        $base = [Microsoft.Win32.Registry]::LocalMachine

        # 1) become the owner (needed before we are allowed to change the DACL)
        $key = $base.OpenSubKey($subKey,
            [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
            [System.Security.AccessControl.RegistryRights]::TakeOwnership)
        if ($null -eq $key) { return $false }
        $acl = $key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None)
        $acl.SetOwner($admins)
        $key.SetAccessControl($acl)
        $key.Close()

        # 2) grant Administrators FullControl, inherited by subkeys
        $key = $base.OpenSubKey($subKey,
            [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
            [System.Security.AccessControl.RegistryRights]::ChangePermissions)
        $acl = $key.GetAccessControl()
        $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
            $admins,
            [System.Security.AccessControl.RegistryRights]::FullControl,
            [System.Security.AccessControl.InheritanceFlags]::ContainerInherit,
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Allow)
        $acl.AddAccessRule($rule)
        $key.SetAccessControl($acl)
        $key.Close()

        Write-Host "   Took ownership and granted Administrators FullControl on $target" -Fore Green
        return $true
    }
    catch {
        Write-Host "   Take-ownership failed on ${target}: $($_.Exception.Message)" -Fore Red
        return $false
    }
}

function Set-PlayrRegistryValue {
    param(
        [Parameter(Mandatory = $true)] [string] $Path,
        [Parameter(Mandatory = $true)] [string] $Name,
        [Parameter(Mandatory = $true)] $Value,
        [ValidateSet('DWord', 'String')] [string] $Type = 'DWord'
    )
    # HKLM changes are machine-wide and need elevation. When not running as Administrator,
    # skip them cleanly (cause #1) rather than throwing UnauthorizedAccessException.
    if (($Path -like 'HKLM:*') -and (-not $script:IsElevated)) {
        Write-Host "=> SKIPPED $Path\$Name (requires Administrator - cause #1, see note above)" -Fore Yellow
        return $false
    }

    if (Invoke-PlayrRegistryWrite -Path $Path -Name $Name -Value $Value -Type $Type) {
        Write-Host "=> Set $Path\$Name = $Value" -Fore Green
        return $true
    }

    # Write failed. For HKCU this is unusual; just report it.
    if ($Path -notlike 'HKLM:*') {
        Write-Host "=> FAILED to set $Path\$Name : $($script:LastRegistryError.Exception.Message)" -Fore Red
        return $false
    }

    # HKLM failure: explain the likely cause (#1 vs #2/#3)...
    Write-PlayrRegistryFailureDiagnosis -Path $Path -ErrorRecord $script:LastRegistryError

    # ...and, if enabled and we are elevated, try the cause #2 remedy: take ownership + retry.
    if ($script:AttemptTakeOwnership -and $script:IsElevated) {
        Write-Host "   Attempting to take ownership of the key and retry..." -Fore Yellow
        if (Repair-PlayrHklmKeyPermissions -Path $Path) {
            if (Invoke-PlayrRegistryWrite -Path $Path -Name $Name -Value $Value -Type $Type) {
                Write-Host "=> Set $Path\$Name = $Value (after taking ownership)" -Fore Green
                return $true
            }
            Write-Host "=> STILL FAILED after taking ownership: $($script:LastRegistryError.Exception.Message)" -Fore Red
            Write-Host "   This strongly indicates cause #3 (managed by MDM/Group Policy) or blocking security software." -Fore Red
        }
    }
    return $false
}

# Fallback for when the Widgets policy write (HKLM\...\Dsh\AllowNewsAndInterests) is
# refused (cause #2 ACL-locked, or cause #3 managed): remove the Widgets component itself
# instead of touching the policy key. This is an Appx/MSIX uninstall, so it works on all
# Windows 11 editions (Home/Pro/Enterprise) - it does NOT require Enterprise (that is only
# needed for Shell Launcher). Note: a future Windows feature update can reinstall it, so
# this may need re-running. (Manual alternative: winget uninstall "Windows Web Experience Pack".)
function Disable-PlayrWidgetsViaAppx {
    if (-not $script:IsElevated) {
        Write-Host "   Cannot remove the Widgets component without Administrator rights - skipping Appx fallback." -Fore Yellow
        return $false
    }
    # The Widgets board ships as the "Windows Web Experience Pack"; the runtime is a
    # separate package on some builds. Match both.
    $patterns = @('*WebExperience*', '*WidgetsPlatformRuntime*')
    $removedAny = $false

    foreach ($pat in $patterns) {
        # 1) Remove the installed package for all existing user profiles.
        try {
            $pkgs = Get-AppxPackage -AllUsers -Name $pat -ErrorAction SilentlyContinue
            foreach ($pkg in $pkgs) {
                try {
                    Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                    Write-Host "   Removed Appx package: $($pkg.Name)" -Fore Green
                    $removedAny = $true
                }
                catch {
                    Write-Host "   Could not remove Appx package $($pkg.Name): $($_.Exception.Message)" -Fore Red
                }
            }
        }
        catch {
            Write-Host "   Get-AppxPackage failed for ${pat}: $($_.Exception.Message)" -Fore Yellow
        }

        # 2) Remove the provisioned package so it is not reinstalled for NEW user profiles.
        try {
            $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like $pat }
            foreach ($pp in $prov) {
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName -ErrorAction Stop | Out-Null
                    Write-Host "   Removed provisioned package: $($pp.DisplayName)" -Fore Green
                    $removedAny = $true
                }
                catch {
                    Write-Host "   Could not remove provisioned package $($pp.DisplayName): $($_.Exception.Message)" -Fore Red
                }
            }
        }
        catch {
            Write-Host "   Get-AppxProvisionedPackage failed for ${pat}: $($_.Exception.Message)" -Fore Yellow
        }
    }

    if ($removedAny) {
        Write-Host "=> Widgets component removed via Appx (a Windows feature update may reinstall it)." -Fore Green
    }
    else {
        Write-Host "=> Widgets component not found/removed; it may already be absent or the removal was blocked." -Fore Yellow
    }
    return $removedAny
}

Write-Host "Hardening the Windows 11 taskbar so it stays hidden behind full-screen playback:"
if (-not $script:IsElevated) {
    Write-Host "=> NOTE: not running as Administrator - machine-wide (HKLM) settings such as fully" -Fore Yellow
    Write-Host "         disabling Widgets will be skipped. Per-user settings will still be applied." -Fore Yellow
    Write-Host "         Re-run PrepareForPlayr.ps1 as Administrator to apply the machine-wide settings." -Fore Yellow
}

###############################################################################
#
# 1. Disable Windows 11 Widgets / News and interests
#    The widgets board (weather/news on the taskbar) updates in the background and is
#    a common cause of the taskbar re-appearing over a full-screen app.
#
###############################################################################
# Policy-level disable of the whole widgets experience (strongest, survives updates)
$dshOk = Set-PlayrRegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0
if (-not $dshOk) {
    # The policy key could not be written (ACL-locked or managed). Disable Widgets by
    # removing the component itself so it is still gone without touching the policy key.
    Write-Host "   Widgets policy write was refused; falling back to removing the Widgets component..." -Fore Yellow
    Disable-PlayrWidgetsViaAppx | Out-Null
}
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
