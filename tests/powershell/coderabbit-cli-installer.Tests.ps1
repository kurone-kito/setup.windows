BeforeAll {
  . (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'libs', 'coderabbit-cli-installer.ps1')
}

Describe 'Add-CoderabbitCliToProcessPath' {
  BeforeEach {
    $script:originalPath = $env:Path
  }

  AfterEach {
    $env:Path = $script:originalPath
  }

  It 'appends the install dir when not already present' {
    $env:Path = '/existing/one;/existing/two'

    Add-CoderabbitCliToProcessPath -InstallDir '/coderabbit/bin'

    $env:Path | Should -Match ([regex]::Escape('/coderabbit/bin'))
  }

  It 'does not duplicate an entry that only differs by case or a trailing slash' {
    $env:Path = '/Existing/CODERABBIT/BIN/;/existing/two'

    Add-CoderabbitCliToProcessPath -InstallDir '/existing/coderabbit/bin'

    ($env:Path -split ';' | Where-Object { $_ -ne '' }).Count | Should -Be 2
  }

  It 'no-ops instead of throwing when InstallDir is null or empty' {
    $env:Path = '/existing/one'

    { Add-CoderabbitCliToProcessPath -InstallDir $null } | Should -Not -Throw
    { Add-CoderabbitCliToProcessPath -InstallDir '' } | Should -Not -Throw
    $env:Path | Should -Be '/existing/one'
  }
}

Describe 'Invoke-CoderabbitCliInstaller' {
  BeforeEach {
    $script:hadOriginalCi = Test-Path Env:\CI
    $script:originalCi = if ($script:hadOriginalCi) { $env:CI } else { $null }
  }

  AfterEach {
    if ($script:hadOriginalCi) {
      $env:CI = $script:originalCi
    }
    else {
      Remove-Item -Path Env:\CI -ErrorAction SilentlyContinue
    }
  }

  It 'returns a non-zero exit code instead of throwing when the download fails' {
    Mock Invoke-WebRequest { throw [System.Net.WebException]::new('Name or service not known') }
    Mock Start-Process { }

    $exitCode = Invoke-CoderabbitCliInstaller -ErrorAction SilentlyContinue
    $exitCode | Should -Be 1

    Should -Invoke Start-Process -Times 0
  }

  It 'removes the temp script even when the download fails' {
    Mock Invoke-WebRequest { throw [System.Net.WebException]::new('Name or service not known') }
    Mock Start-Process { }
    Mock Remove-Item { }

    Invoke-CoderabbitCliInstaller -ErrorAction SilentlyContinue | Out-Null

    Should -Invoke Remove-Item -Times 1
  }

  It 'returns the child process exit code on success' {
    Mock Invoke-WebRequest { }
    Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }

    Invoke-CoderabbitCliInstaller | Should -Be 0
  }

  It 'removes the temp script after a successful install too' {
    Mock Invoke-WebRequest { }
    Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }
    Mock Remove-Item { }

    Invoke-CoderabbitCliInstaller | Out-Null

    Should -Invoke Remove-Item -Times 1
  }

  It 'sets $env:CI to 1 only while Start-Process is running, when CI was previously unset' {
    Remove-Item -Path Env:\CI -ErrorAction SilentlyContinue

    Mock Invoke-WebRequest { }
    Mock Start-Process {
      $script:ciDuringInstall = $env:CI
      [pscustomobject]@{ ExitCode = 0 }
    }

    Invoke-CoderabbitCliInstaller | Out-Null

    $script:ciDuringInstall | Should -Be '1'
    (Test-Path Env:\CI) | Should -Be $false
  }

  It 'restores a pre-existing $env:CI value after Start-Process returns' {
    $env:CI = 'previous-value'

    Mock Invoke-WebRequest { }
    Mock Start-Process {
      $script:ciDuringInstall = $env:CI
      [pscustomobject]@{ ExitCode = 0 }
    }

    Invoke-CoderabbitCliInstaller | Out-Null

    $script:ciDuringInstall | Should -Be '1'
    $env:CI | Should -Be 'previous-value'
  }

  It 'restores $env:CI even when Start-Process throws' {
    $env:CI = 'previous-value'

    Mock Invoke-WebRequest { }
    Mock Start-Process { throw 'boom' }

    { Invoke-CoderabbitCliInstaller } | Should -Throw

    $env:CI | Should -Be 'previous-value'
  }
}

Describe 'Sync-CoderabbitCli' {
  BeforeEach {
    Mock Get-Command -ParameterFilter { $Name -eq 'git' } { [pscustomobject]@{ Name = 'git' } }
  }

  It 'skips installation and does not touch PATH when git is not found' {
    Mock Get-Command -ParameterFilter { $Name -eq 'git' } { $null }
    Mock Add-CoderabbitCliToProcessPath { }
    Mock Invoke-CoderabbitCliInstaller { 0 }

    Sync-CoderabbitCli -WarningAction SilentlyContinue

    Should -Invoke Invoke-CoderabbitCliInstaller -Times 0
    Should -Invoke Add-CoderabbitCliToProcessPath -Times 0
  }

  It 'writes a warning, not a terminating error, when git is not found' {
    Mock Get-Command -ParameterFilter { $Name -eq 'git' } { $null }
    Mock Invoke-CoderabbitCliInstaller { 0 }

    { Sync-CoderabbitCli -WarningAction SilentlyContinue } | Should -Not -Throw
  }

  It 'always invokes the installer, even on a second consecutive call' {
    Mock Add-CoderabbitCliToProcessPath { }
    Mock Invoke-CoderabbitCliInstaller { 0 }

    Sync-CoderabbitCli
    Sync-CoderabbitCli

    Should -Invoke Invoke-CoderabbitCliInstaller -Times 2
  }

  It 'adds the install dir to PATH both before and after a successful install' {
    Mock Add-CoderabbitCliToProcessPath { }
    Mock Invoke-CoderabbitCliInstaller { 0 }

    Sync-CoderabbitCli

    Should -Invoke Add-CoderabbitCliToProcessPath -Times 2
  }

  It 'writes a non-terminating error and does not throw when the installer exits non-zero' {
    Mock Add-CoderabbitCliToProcessPath { }
    Mock Invoke-CoderabbitCliInstaller { 1 }

    { Sync-CoderabbitCli -ErrorAction SilentlyContinue } | Should -Not -Throw
  }

  It 'does not add the install dir to PATH a second time when the installer fails' {
    Mock Add-CoderabbitCliToProcessPath { }
    Mock Invoke-CoderabbitCliInstaller { 1 }

    Sync-CoderabbitCli -ErrorAction SilentlyContinue

    Should -Invoke Add-CoderabbitCliToProcessPath -Times 1
  }
}
