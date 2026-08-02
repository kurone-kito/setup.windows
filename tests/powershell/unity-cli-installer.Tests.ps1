BeforeAll {
  . (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'libs', 'unity-cli-installer.ps1')
}

Describe 'Test-UnityCliCurrent' {
  It 'returns $false when the CLI is not on PATH' {
    $installed = @{ Found = $false; Output = ''; ExitCode = $null }

    Test-UnityCliCurrent -Installed $installed -Target '1.0.0-beta.3' | Should -Be $false
  }

  It 'returns $false when `unity --version` exited non-zero' {
    $installed = @{ Found = $true; Output = '1.0.0-beta.3'; ExitCode = 1 }

    Test-UnityCliCurrent -Installed $installed -Target '1.0.0-beta.3' | Should -Be $false
  }

  It 'returns $true when the declared Target appears in the output' {
    $installed = @{ Found = $true; Output = 'unity-cli 1.0.0-beta.3'; ExitCode = 0 }

    Test-UnityCliCurrent -Installed $installed -Target '1.0.0-beta.3' | Should -Be $true
  }

  It 'returns $false when the output names a different version' {
    $installed = @{ Found = $true; Output = 'unity-cli 1.0.0-beta.2'; ExitCode = 0 }

    Test-UnityCliCurrent -Installed $installed -Target '1.0.0-beta.3' | Should -Be $false
  }
}

Describe 'Add-UnityCliToProcessPath' {
  BeforeEach {
    $script:originalPath = $env:Path
  }

  AfterEach {
    $env:Path = $script:originalPath
  }

  It 'appends the install dir when not already present' {
    $env:Path = '/existing/one;/existing/two'

    Add-UnityCliToProcessPath -InstallDir '/unity/bin'

    $env:Path | Should -Match ([regex]::Escape('/unity/bin'))
  }

  It 'does not duplicate an entry that only differs by case or a trailing slash' {
    $env:Path = '/Existing/UNITY/BIN/;/existing/two'

    Add-UnityCliToProcessPath -InstallDir '/existing/unity/bin'

    ($env:Path -split ';' | Where-Object { $_ -ne '' }).Count | Should -Be 2
  }

  It 'no-ops instead of throwing when InstallDir is null or empty' {
    $env:Path = '/existing/one'

    { Add-UnityCliToProcessPath -InstallDir $null } | Should -Not -Throw
    { Add-UnityCliToProcessPath -InstallDir '' } | Should -Not -Throw
    $env:Path | Should -Be '/existing/one'
  }
}

Describe 'Invoke-UnityCliInstaller' {
  It 'returns a non-zero exit code instead of throwing when the download fails' {
    Mock Invoke-WebRequest { throw [System.Net.WebException]::new('Name or service not known') }
    Mock Start-Process { }

    $exitCode = Invoke-UnityCliInstaller -Target '1.0.0-beta.3' -Channel 'beta' -ErrorAction SilentlyContinue
    $exitCode | Should -Be 1

    Should -Invoke Start-Process -Times 0
  }

  It 'removes the temp script even when the download fails' {
    Mock Invoke-WebRequest { throw [System.Net.WebException]::new('Name or service not known') }
    Mock Start-Process { }
    Mock Remove-Item { }

    Invoke-UnityCliInstaller -Target '1.0.0-beta.3' -Channel 'beta' -ErrorAction SilentlyContinue | Out-Null

    Should -Invoke Remove-Item -Times 1
  }
}

Describe 'Sync-UnityCli' {
  BeforeAll {
    $script:configPath = Join-Path -Path $TestDrive -ChildPath 'runtime-versions.psd1'
    Set-Content -Path $script:configPath -Value @'
@{
  UnityCli = @{
    Target  = '1.0.0-beta.3'
    Channel = 'beta'
  }
}
'@
  }

  It 'skips installation when the CLI already matches Target' {
    Mock Get-InstalledUnityCliVersion { @{ Found = $true; Output = '1.0.0-beta.3'; ExitCode = 0 } }
    Mock Invoke-UnityCliInstaller { 0 }
    Mock Add-UnityCliToProcessPath { }

    Sync-UnityCli -ConfigPath $script:configPath

    Should -Invoke Invoke-UnityCliInstaller -Times 0
  }

  It 'installs when the CLI is missing, then does not reinstall on a second run (idempotent)' {
    $script:installed = $false
    Mock Get-InstalledUnityCliVersion {
      if ($script:installed) {
        return @{ Found = $true; Output = '1.0.0-beta.3'; ExitCode = 0 }
      }
      return @{ Found = $false; Output = ''; ExitCode = $null }
    }
    Mock Invoke-UnityCliInstaller {
      $script:installed = $true
      return 0
    }
    Mock Add-UnityCliToProcessPath { }

    Sync-UnityCli -ConfigPath $script:configPath
    Should -Invoke Invoke-UnityCliInstaller -Times 1

    Sync-UnityCli -ConfigPath $script:configPath
    Should -Invoke Invoke-UnityCliInstaller -Times 1
  }

  It 'writes a non-terminating error and does not throw when the installer exits non-zero' {
    Mock Get-InstalledUnityCliVersion { @{ Found = $false; Output = ''; ExitCode = $null } }
    Mock Invoke-UnityCliInstaller { 1 }
    Mock Add-UnityCliToProcessPath { }

    { Sync-UnityCli -ConfigPath $script:configPath -ErrorAction SilentlyContinue } | Should -Not -Throw
  }

  It 'writes a non-terminating error and does not throw when the config file is missing' {
    { Sync-UnityCli -ConfigPath (Join-Path $TestDrive 'does-not-exist.psd1') -ErrorAction SilentlyContinue } | Should -Not -Throw
  }

  It 'writes a non-terminating error and does not throw when the UnityCli entry is missing' {
    $path = Join-Path -Path $TestDrive -ChildPath 'no-unity-cli.psd1'
    Set-Content -Path $path -Value "@{ Node = @{} }"

    { Sync-UnityCli -ConfigPath $path -ErrorAction SilentlyContinue } | Should -Not -Throw
  }

  It 'writes a non-terminating error and does not throw when UnityCli is missing Target/Channel' {
    $path = Join-Path -Path $TestDrive -ChildPath 'incomplete-unity-cli.psd1'
    Set-Content -Path $path -Value "@{ UnityCli = @{ Target = '1.0.0-beta.3' } }"

    { Sync-UnityCli -ConfigPath $path -ErrorAction SilentlyContinue } | Should -Not -Throw
  }
}
