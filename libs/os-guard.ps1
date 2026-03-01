<#
.SYNOPSIS
Detects the current OS version and edition, and warns or blocks
execution based on the support status.
#>
Set-StrictMode -Version Latest

function Test-OsSupport {
  $os = Get-CimInstance Win32_OperatingSystem
  $build = [int]$os.BuildNumber
  $caption = $os.Caption
  $version = $os.Version

  # Detect edition
  $edition = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name EditionID -ErrorAction SilentlyContinue).EditionID

  $isServer = $caption -match 'Server'
  $isPro = $edition -match 'Professional|Enterprise|Education'
  $isHome = $edition -match 'Core' -or $edition -match 'Home'

  # Windows 11: Build 22000+
  # Windows 10 22H2: Build 19045
  # Windows 10 (older): Build < 19045

  if ($build -ge 22000) {
    # Windows 11
    if ($isPro) {
      Write-Host '[OS] Windows 11 Pro / Enterprise detected. Fully supported.' -ForegroundColor Green
      return @{ Supported = $true; Tier = 1; IsServer = $false }
    }
    else {
      Write-Host '[OS] Windows 11 Home detected. Supported (some features like Hyper-V may be unavailable).' -ForegroundColor Yellow
      return @{ Supported = $true; Tier = 2; IsServer = $false }
    }
  }
  elseif ($build -eq 19045) {
    # Windows 10 22H2
    Write-Warning '[OS] Windows 10 22H2 detected. Windows 10 has reached end of support (October 2025).'
    Write-Warning '     This setup will attempt to run, but some packages may not work correctly.'
    if ($isPro) {
      return @{ Supported = $true; Tier = 3; IsServer = $false }
    }
    else {
      return @{ Supported = $true; Tier = 4; IsServer = $false }
    }
  }
  elseif ($build -ge 17763 -and $isServer) {
    # Windows Server 2019+ (Build 17763 = WS2019, 20348 = WS2022, 26100 = WS2025)
    Write-Warning '[OS] Windows Server detected. Supported with limited testing.'
    if ($build -lt 20348) {
      Write-Warning '     Windows Server 2019: Mainstream support has ended. Consider upgrading.'
    }
    return @{ Supported = $true; Tier = 5; IsServer = $true }
  }
  elseif ($build -ge 10240 -and $build -lt 19045) {
    # Windows 10 older than 22H2
    Write-Error '[OS] Windows 10 (build $build) is too old. Please update to 22H2 (build 19045) or upgrade to Windows 11.'
    return @{ Supported = $false; Tier = 99; IsServer = $false }
  }
  else {
    Write-Error "[OS] Unsupported OS detected (Build: $build). This setup requires Windows 10 22H2 or later."
    return @{ Supported = $false; Tier = 99; IsServer = $isServer }
  }
  <#
  .SYNOPSIS
  Tests whether the current OS is supported and returns the support tier.
  Tier 1: Windows 11 Pro/Enterprise (best)
  Tier 2: Windows 11 Home
  Tier 3: Windows 10 22H2 Pro/Enterprise (EOL warning)
  Tier 4: Windows 10 22H2 Home (EOL warning)
  Tier 5: Windows Server (limited)
  .OUTPUTS
  Hashtable with Supported (bool), Tier (int), IsServer (bool)
  #>
}

Export-ModuleMember -Function Test-OsSupport
