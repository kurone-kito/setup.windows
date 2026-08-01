BeforeAll {
  # Get-CimInstance ships in the Windows-only CimCmdlets module, so it
  # does not exist on the Linux runner Pester runs on here. A global
  # placeholder makes it mockable; Test-OsSupport never calls the real
  # cmdlet under test, only this mock.
  function global:Get-CimInstance { }

  . (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'libs', 'os-guard.ps1')

  # GitHub Actions' `shell: pwsh` steps implicitly set
  # $ErrorActionPreference = 'Stop' for the whole step, which turns
  # Test-OsSupport's non-terminating Write-Error calls (its documented
  # signal for the unsupported-OS branches) into terminating exceptions
  # here -- unlike a plain local `pwsh -c` invocation, where the
  # session default of 'Continue' lets those branches return normally.
  # Reset it explicitly so this suite behaves the same in both places.
  $ErrorActionPreference = 'Continue'
}

Describe 'Test-OsSupport' {
  Context 'boundary and gap cases' {
    It 'returns Tier <ExpectedTier> (Supported=<ExpectedSupported>) for build <BuildNumber>, <Description>' -ForEach @(
      @{ Description = 'Windows 11 Pro, the build-22000 lower boundary'; BuildNumber = '22000'; Caption = 'Microsoft Windows 11 Pro'; EditionID = 'Professional'; ExpectedSupported = $true; ExpectedTier = 2; ExpectedIsServer = $false }
      @{ Description = 'Windows 11 Home, the build-22000 lower boundary'; BuildNumber = '22000'; Caption = 'Microsoft Windows 11 Home'; EditionID = 'Core'; ExpectedSupported = $true; ExpectedTier = 2; ExpectedIsServer = $false }
      @{ Description = 'Windows 10 22H2 Pro, the build-19045 EOL-warning boundary'; BuildNumber = '19045'; Caption = 'Microsoft Windows 10 Pro'; EditionID = 'Professional'; ExpectedSupported = $true; ExpectedTier = 3; ExpectedIsServer = $false }
      @{ Description = 'Windows 10 22H2 Home, the build-19045 EOL-warning boundary'; BuildNumber = '19045'; Caption = 'Microsoft Windows 10 Home'; EditionID = 'Core'; ExpectedSupported = $true; ExpectedTier = 4; ExpectedIsServer = $false }
      @{ Description = 'one build below the 22H2 boundary'; BuildNumber = '19044'; Caption = 'Microsoft Windows 10 Pro'; EditionID = 'Professional'; ExpectedSupported = $false; ExpectedTier = 99; ExpectedIsServer = $false }
      @{ Description = 'the unnamed gap above 22H2 and below Windows 11'; BuildNumber = '21999'; Caption = 'Microsoft Windows 10 Pro'; EditionID = 'Professional'; ExpectedSupported = $false; ExpectedTier = 99; ExpectedIsServer = $false }
      @{ Description = 'Windows Server 2019, the build-17763 server floor'; BuildNumber = '17763'; Caption = 'Microsoft Windows Server 2019 Standard'; EditionID = 'ServerStandard'; ExpectedSupported = $true; ExpectedTier = 5; ExpectedIsServer = $true }
      @{ Description = 'pre-Windows-10 (build below 10240)'; BuildNumber = '10239'; Caption = 'Microsoft Windows 8.1 Pro'; EditionID = 'Professional'; ExpectedSupported = $false; ExpectedTier = 99; ExpectedIsServer = $false }
    ) {
      Mock Get-CimInstance {
        [pscustomobject]@{ BuildNumber = $BuildNumber; Caption = $Caption }
      }
      Mock Get-ItemProperty {
        [pscustomobject]@{ EditionID = $EditionID }
      }

      $result = Test-OsSupport

      $result.Supported | Should -Be $ExpectedSupported
      $result.Tier | Should -Be $ExpectedTier
      $result.IsServer | Should -Be $ExpectedIsServer
      Should -Invoke Get-CimInstance -Times 1
      Should -Invoke Get-ItemProperty -Times 1
    }
  }
}
