# Ensures a Windows batch file uses CRLF line endings.
# cmd.exe cannot resolve labels (:LOG, :WAIT_SECONDS, ...) in an LF-only .cmd file.
# GitHub "Download ZIP" serves the git blob as stored. When this repo is maintained
# on macOS or Linux, that blob has LF, and .gitattributes eol=crlf is not applied.
# Called by StartChromeForPlayr.cmd and StartChromeOnMultipleScreens.cmd before any
# label is used. PowerShell itself accepts LF, so this file may stay LF.
param(
  [Parameter(Mandatory = $true)][string]$CurrentScript,
  [Parameter(Mandatory = $true)][string]$FixedCopy,
  [Parameter(Mandatory = $true)][string]$GoFlag,
  [Parameter(Mandatory = $true)][string]$OriginalScript
)

$ErrorActionPreference = 'Stop'

function Test-HasBareLf {
  param([byte[]]$Bytes)
  $prev = -1
  foreach ($b in $Bytes) {
    $bi = [int]$b
    if ($bi -eq 10 -and $prev -ne 13) { return $true }
    $prev = $bi
  }
  return $false
}

function Write-CrlfCopy {
  param([string]$SourcePath, [string]$DestPath)
  $bytes = [System.IO.File]::ReadAllBytes($SourcePath)
  $ms = New-Object System.IO.MemoryStream
  $prev = -1
  foreach ($b in $bytes) {
    $bi = [int]$b
    if ($bi -eq 10 -and $prev -ne 13) { $ms.WriteByte([byte]13) }
    $ms.WriteByte([byte]$bi)
    $prev = $bi
  }
  $dir = [System.IO.Path]::GetDirectoryName($DestPath)
  if (-not [string]::IsNullOrEmpty($dir) -and -not [System.IO.Directory]::Exists($dir)) {
    [void][System.IO.Directory]::CreateDirectory($dir)
  }
  $tmp = "$DestPath.tmp"
  [System.IO.File]::WriteAllBytes($tmp, $ms.ToArray())
  if ([System.IO.File]::Exists($DestPath)) {
    [System.IO.File]::Delete($DestPath)
  }
  [System.IO.File]::Move($tmp, $DestPath)
}

function Remove-GoFlag {
  if ([System.IO.File]::Exists($GoFlag)) {
    [System.IO.File]::Delete($GoFlag)
  }
}

if (-not [System.IO.File]::Exists($CurrentScript)) {
  [Console]::Error.WriteLine("Playr: batch file not found: $CurrentScript")
  exit 1
}

$currentBytes = [System.IO.File]::ReadAllBytes($CurrentScript)
if (Test-HasBareLf $currentBytes) {
  try {
    Write-CrlfCopy -SourcePath $CurrentScript -DestPath $FixedCopy
    $flagDir = [System.IO.Path]::GetDirectoryName($GoFlag)
    if (-not [string]::IsNullOrEmpty($flagDir) -and -not [System.IO.Directory]::Exists($flagDir)) {
      [void][System.IO.Directory]::CreateDirectory($flagDir)
    }
    [System.IO.File]::WriteAllBytes($GoFlag, (New-Object byte[] 0))
  } catch {
    Remove-GoFlag
    [Console]::Error.WriteLine("Playr: could not write a CRLF copy of this script: $($_.Exception.Message)")
    exit 1
  }
  exit 0
}

Remove-GoFlag

# The running file is already CRLF (often the TEMP copy). Best-effort: rewrite the
# downloaded original so the next start does not need the TEMP copy. Ignore failure
# when that folder is read-only; this run already has a CRLF copy.
try {
  $currentFull = [System.IO.Path]::GetFullPath($CurrentScript)
  $originalFull = [System.IO.Path]::GetFullPath($OriginalScript)
  if (-not $currentFull.Equals($originalFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    if ([System.IO.File]::Exists($OriginalScript)) {
      $originalBytes = [System.IO.File]::ReadAllBytes($OriginalScript)
      if (Test-HasBareLf $originalBytes) {
        Write-CrlfCopy -SourcePath $OriginalScript -DestPath $OriginalScript
      }
    }
  }
} catch {
  [Console]::Error.WriteLine("Playr: left the original script unchanged ($($_.Exception.Message)). This run uses the CRLF copy.")
}

exit 0
