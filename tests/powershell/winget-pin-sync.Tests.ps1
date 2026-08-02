BeforeAll {
  . (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'libs', 'winget-pin-sync.ps1')
}

Describe 'ConvertFrom-WinGetPinListOutput' {
  It 'parses Pinning and Blocking pins with an empty Version column' {
    $output = @'
Id                   Source Version Pin type
--------------------------------------------
Unity.UnityHub       winget         Blocking
Microsoft.PowerShell winget         Pinning
'@
    $pins = @(ConvertFrom-WinGetPinListOutput -Output $output)

    $pins.Count | Should -Be 2
    ($pins | Where-Object Id -EQ 'Unity.UnityHub').PinType | Should -Be 'Blocking'
    ($pins | Where-Object Id -EQ 'Unity.UnityHub').Version | Should -Be ''
    ($pins | Where-Object Id -EQ 'Microsoft.PowerShell').PinType | Should -Be 'Pinning'
  }

  It 'parses a Gating pin with a version range in the Version column' {
    $output = @'
Id                    Source Version Pin type
---------------------------------------------
VMware.WorkstationPro winget 16.*    Gating
'@
    $pins = @(ConvertFrom-WinGetPinListOutput -Output $output)

    $pins.Count | Should -Be 1
    $pins[0].PinType | Should -Be 'Gating'
    $pins[0].Version | Should -Be '16.*'
  }

  It 'returns an empty array when there is no header row (no pins set)' {
    $pins = ConvertFrom-WinGetPinListOutput -Output 'No pinned packages found.'

    $pins | Should -BeNullOrEmpty
  }

  It 'returns an empty array for an empty string' {
    $pins = ConvertFrom-WinGetPinListOutput -Output ''

    $pins | Should -BeNullOrEmpty
  }

  It 'returns an empty array when the header is present with no data rows' {
    $output = @'
Id                Source Version Pin type
------------------------------------------
'@
    $pins = ConvertFrom-WinGetPinListOutput -Output $output

    $pins | Should -BeNullOrEmpty
  }
}

Describe 'Get-CurrentWinGetPins' {
  It 'returns parsed pins on success' {
    Mock Invoke-WinGetPinListCommand {
      @{
        ExitCode = 0
        Output   = @'
Id             Source Version Pin type
--------------------------------------
Unity.UnityHub winget         Blocking
'@
      }
    }

    $pins = @(Get-CurrentWinGetPins)

    $pins.Count | Should -Be 1
    $pins[0].Id | Should -Be 'Unity.UnityHub'
  }

  It 'returns an empty array instead of throwing when the exit code is non-zero' {
    Mock Invoke-WinGetPinListCommand {
      @{ ExitCode = 1; Output = 'winget: command failed' }
    }

    { Get-CurrentWinGetPins -ErrorAction SilentlyContinue } | Should -Not -Throw
    Get-CurrentWinGetPins -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
  }
}

Describe 'Test-PinnedPackageEntry' {
  It 'accepts a well-formed Pinning entry' {
    Test-PinnedPackageEntry -Entry @{ Id = 'a'; Source = 'winget'; PinType = 'Pinning'; Reason = 'r' } | Should -Be $true
  }

  It 'accepts a well-formed Gating entry with VersionRange' {
    Test-PinnedPackageEntry -Entry @{ Id = 'a'; Source = 'winget'; PinType = 'Gating'; Reason = 'r'; VersionRange = '1.2.*' } | Should -Be $true
  }

  It 'rejects a Gating entry missing VersionRange' {
    Test-PinnedPackageEntry -Entry @{ Id = 'a'; Source = 'winget'; PinType = 'Gating'; Reason = 'r' } | Should -Be $false
  }

  It 'rejects an entry missing Reason' {
    Test-PinnedPackageEntry -Entry @{ Id = 'a'; Source = 'winget'; PinType = 'Pinning' } | Should -Be $false
  }

  It 'rejects an unknown PinType' {
    Test-PinnedPackageEntry -Entry @{ Id = 'a'; Source = 'winget'; PinType = 'Unknown'; Reason = 'r' } | Should -Be $false
  }
}

Describe 'Get-WinGetPinAddArguments' {
  It 'builds a plain pin add command for Pinning' {
    $arguments = Get-WinGetPinAddArguments -Entry @{ Id = 'a.b'; Source = 'winget'; PinType = 'Pinning'; Reason = 'r' }

    ($arguments -join ' ') | Should -Be 'pin add --id a.b -s winget --disable-interactivity --accept-source-agreements'
  }

  It 'adds --blocking for Blocking' {
    $arguments = Get-WinGetPinAddArguments -Entry @{ Id = 'a.b'; Source = 'winget'; PinType = 'Blocking'; Reason = 'r' }

    ($arguments -join ' ') | Should -Be 'pin add --id a.b -s winget --disable-interactivity --accept-source-agreements --blocking'
  }

  It 'adds --version and the range for Gating' {
    $arguments = Get-WinGetPinAddArguments -Entry @{ Id = 'a.b'; Source = 'winget'; PinType = 'Gating'; Reason = 'r'; VersionRange = '1.2.*' }

    ($arguments -join ' ') | Should -Be 'pin add --id a.b -s winget --disable-interactivity --accept-source-agreements --version 1.2.*'
  }

  It 'throws for an unknown PinType (defensive guard)' {
    { Get-WinGetPinAddArguments -Entry @{ Id = 'a.b'; Source = 'winget'; PinType = 'Unknown'; Reason = 'r' } } | Should -Throw
  }
}

Describe 'Get-WinGetPinDrift' {
  It 'classifies a declared pin absent on the machine as ToAdd' {
    $drift = Get-WinGetPinDrift -Declared @(@{ Id = 'a'; Source = 'winget'; PinType = 'Blocking'; Reason = 'r' }) -Current @()

    $drift.ToAdd.Count | Should -Be 1
    $drift.Matching | Should -BeNullOrEmpty
    $drift.Mismatched | Should -BeNullOrEmpty
    $drift.Undeclared | Should -BeNullOrEmpty
  }

  It 'classifies a declared pin present with the same type as Matching' {
    $declared = @{ Id = 'a'; Source = 'winget'; PinType = 'Blocking'; Reason = 'r' }
    $current = @{ Id = 'a'; Source = 'winget'; PinType = 'Blocking'; Version = '' }

    $drift = Get-WinGetPinDrift -Declared @($declared) -Current @($current)

    $drift.Matching.Count | Should -Be 1
    $drift.ToAdd | Should -BeNullOrEmpty
    $drift.Mismatched | Should -BeNullOrEmpty
  }

  It 'classifies a present pin not in the declaration as Undeclared' {
    $current = @{ Id = 'b'; Source = 'winget'; PinType = 'Pinning'; Version = '' }

    $drift = Get-WinGetPinDrift -Declared @() -Current @($current)

    $drift.Undeclared.Count | Should -Be 1
    $drift.Undeclared[0].Id | Should -Be 'b'
  }

  It 'classifies a declared pin present with a different type as Mismatched' {
    $declared = @{ Id = 'a'; Source = 'winget'; PinType = 'Blocking'; Reason = 'r' }
    $current = @{ Id = 'a'; Source = 'winget'; PinType = 'Pinning'; Version = '' }

    $drift = Get-WinGetPinDrift -Declared @($declared) -Current @($current)

    $drift.Mismatched.Count | Should -Be 1
    $drift.Matching | Should -BeNullOrEmpty
    $drift.ToAdd | Should -BeNullOrEmpty
  }

  It 'classifies a Gating pin with a different version range as Mismatched' {
    $declared = @{ Id = 'a'; Source = 'winget'; PinType = 'Gating'; Reason = 'r'; VersionRange = '2.*' }
    $current = @{ Id = 'a'; Source = 'winget'; PinType = 'Gating'; Version = '1.*' }

    $drift = Get-WinGetPinDrift -Declared @($declared) -Current @($current)

    $drift.Mismatched.Count | Should -Be 1
  }

  It 'does not confuse packages with the same Id from a different Source' {
    $declared = @{ Id = 'a'; Source = 'winget'; PinType = 'Blocking'; Reason = 'r' }
    $current = @{ Id = 'a'; Source = 'msstore'; PinType = 'Blocking'; Version = '' }

    $drift = Get-WinGetPinDrift -Declared @($declared) -Current @($current)

    $drift.ToAdd.Count | Should -Be 1
    $drift.Undeclared.Count | Should -Be 1
  }
}

Describe 'Sync-WinGetPins' {
  BeforeAll {
    $script:configPath = Join-Path -Path $TestDrive -ChildPath 'pinned-packages.psd1'
    Set-Content -Path $script:configPath -Value @'
@{
  Pins = @(
    @{
      Id      = 'Unity.UnityHub'
      Source  = 'winget'
      PinType = 'Blocking'
      Reason  = 'test reason'
    }
  )
}
'@
  }

  It 'adds a declared pin that is missing' {
    Mock Get-CurrentWinGetPins { @() }
    Mock Invoke-WinGetPinAddCommand { 0 }

    Sync-WinGetPins -ConfigPath $script:configPath

    Should -Invoke Invoke-WinGetPinAddCommand -Times 1 -ParameterFilter {
      ($ArgumentList -join ' ') -eq 'pin add --id Unity.UnityHub -s winget --disable-interactivity --accept-source-agreements --blocking'
    }
  }

  It 'does not re-add a pin that is already applied (idempotent second run)' {
    Mock Get-CurrentWinGetPins { @(@{ Id = 'Unity.UnityHub'; Source = 'winget'; PinType = 'Blocking'; Version = '' }) }
    Mock Invoke-WinGetPinAddCommand { 0 }

    Sync-WinGetPins -ConfigPath $script:configPath

    Should -Invoke Invoke-WinGetPinAddCommand -Times 0
  }

  It 'runs twice with an add on the first run and nothing on the second (end-to-end idempotency)' {
    $script:pinned = @()
    Mock Get-CurrentWinGetPins { $script:pinned }
    Mock Invoke-WinGetPinAddCommand {
      $script:pinned = @(@{ Id = 'Unity.UnityHub'; Source = 'winget'; PinType = 'Blocking'; Version = '' })
      return 0
    }

    Sync-WinGetPins -ConfigPath $script:configPath
    Should -Invoke Invoke-WinGetPinAddCommand -Times 1

    Sync-WinGetPins -ConfigPath $script:configPath
    Should -Invoke Invoke-WinGetPinAddCommand -Times 1
  }

  It 'reports an undeclared pin without attempting to remove it' {
    Mock Get-CurrentWinGetPins { @(@{ Id = 'Unity.UnityHub'; Source = 'winget'; PinType = 'Blocking'; Version = '' }, @{ Id = 'Other.Package'; Source = 'winget'; PinType = 'Pinning'; Version = '' }) }
    Mock Invoke-WinGetPinAddCommand { 0 }

    Sync-WinGetPins -ConfigPath $script:configPath -WarningAction SilentlyContinue

    Should -Invoke Invoke-WinGetPinAddCommand -Times 0
  }

  It 'writes a non-terminating error and does not throw when the config file is missing' {
    { Sync-WinGetPins -ConfigPath (Join-Path $TestDrive 'does-not-exist.psd1') -ErrorAction SilentlyContinue } | Should -Not -Throw
  }

  It 'writes a non-terminating error and does not throw when the Pins entry is missing' {
    $path = Join-Path -Path $TestDrive -ChildPath 'no-pins.psd1'
    Set-Content -Path $path -Value '@{ Other = @{} }'

    { Sync-WinGetPins -ConfigPath $path -ErrorAction SilentlyContinue } | Should -Not -Throw
  }

  It 'skips a malformed entry but still applies the well-formed ones' {
    $path = Join-Path -Path $TestDrive -ChildPath 'mixed-pins.psd1'
    Set-Content -Path $path -Value @'
@{
  Pins = @(
    @{ Id = 'Bad.Entry'; Source = 'winget'; PinType = 'Pinning' }
    @{ Id = 'Good.Entry'; Source = 'winget'; PinType = 'Pinning'; Reason = 'r' }
  )
}
'@
    Mock Get-CurrentWinGetPins { @() }
    Mock Invoke-WinGetPinAddCommand { 0 }

    Sync-WinGetPins -ConfigPath $path -WarningAction SilentlyContinue

    Should -Invoke Invoke-WinGetPinAddCommand -Times 1 -ParameterFilter {
      ($ArgumentList -join ' ') -like '*Good.Entry*'
    }
  }

  It 'aborts without attempting to add pins when the current pin state cannot be determined' {
    Mock Get-CurrentWinGetPins { throw 'winget pin list failed' }
    Mock Invoke-WinGetPinAddCommand { 0 }

    { Sync-WinGetPins -ConfigPath $script:configPath -ErrorAction SilentlyContinue } | Should -Not -Throw

    Should -Invoke Invoke-WinGetPinAddCommand -Times 0
  }
}
