BeforeAll {
  . (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'libs', 'unity-editor-installer.ps1')
}

Describe 'Get-InstalledUnityEditors' {
  It 'returns version strings from a "version" field' {
    Mock Invoke-UnityEditorsListCommand {
      @{
        ExitCode = 0
        Output   = '{"success":true,"command":"editors","data":[{"version":"2022.3.22f1"},{"version":"6000.0.1f1"}],"errors":[],"warnings":[]}'
      }
    }

    Get-InstalledUnityEditors | Should -Be @('2022.3.22f1', '6000.0.1f1')
  }

  It 'falls back to a "Version" field when "version" is absent' {
    Mock Invoke-UnityEditorsListCommand {
      @{
        ExitCode = 0
        Output   = '{"success":true,"command":"editors","data":[{"Version":"2022.3.22f1"}],"errors":[],"warnings":[]}'
      }
    }

    Get-InstalledUnityEditors | Should -Be @('2022.3.22f1')
  }

  It 'returns an empty array when the exit code is non-zero' {
    Mock Invoke-UnityEditorsListCommand {
      @{ ExitCode = 1; Output = 'unity: command failed' }
    }

    Get-InstalledUnityEditors -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
  }

  It 'returns an empty array instead of throwing when the output is not valid JSON' {
    Mock Invoke-UnityEditorsListCommand {
      @{ ExitCode = 0; Output = 'not json' }
    }

    { Get-InstalledUnityEditors -ErrorAction SilentlyContinue } | Should -Not -Throw
    Get-InstalledUnityEditors -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
  }

  It 'returns an empty array when data is empty' {
    Mock Invoke-UnityEditorsListCommand {
      @{
        ExitCode = 0
        Output   = '{"success":true,"command":"editors","data":[],"errors":[],"warnings":[]}'
      }
    }

    Get-InstalledUnityEditors | Should -BeNullOrEmpty
  }

  It 'skips an item where neither "version" nor "Version" is present' {
    Mock Invoke-UnityEditorsListCommand {
      @{
        ExitCode = 0
        Output   = '{"success":true,"command":"editors","data":[{"path":"/no/version/field"},{"version":"2022.3.22f1"}],"errors":[],"warnings":[]}'
      }
    }

    Get-InstalledUnityEditors | Should -Be @('2022.3.22f1')
  }

  It 'returns an empty array instead of throwing under StrictMode when the envelope has no "success" or "data" member' {
    Mock Invoke-UnityEditorsListCommand {
      @{ ExitCode = 0; Output = '{"unexpected":true}' }
    }

    { Get-InstalledUnityEditors -ErrorAction SilentlyContinue } | Should -Not -Throw
    Get-InstalledUnityEditors -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
  }

  It 'returns an empty array instead of throwing under StrictMode when the JSON parses to a bare primitive' {
    Mock Invoke-UnityEditorsListCommand {
      @{ ExitCode = 0; Output = '42' }
    }

    { Get-InstalledUnityEditors -ErrorAction SilentlyContinue } | Should -Not -Throw
    Get-InstalledUnityEditors -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
  }

  It 'returns an empty array instead of throwing under StrictMode when the JSON is a literal null' {
    Mock Invoke-UnityEditorsListCommand {
      @{ ExitCode = 0; Output = 'null' }
    }

    { Get-InstalledUnityEditors -ErrorAction SilentlyContinue } | Should -Not -Throw
    Get-InstalledUnityEditors -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
  }
}

Describe 'Test-UnityEditorInstalled' {
  It 'returns $true on an exact match' {
    Test-UnityEditorInstalled -Installed @('2022.3.22f1') -Target '2022.3.22f1' | Should -Be $true
  }

  It 'returns $false for an unrelated version' {
    Test-UnityEditorInstalled -Installed @('2021.1.1f1') -Target '2022.3.22f1' | Should -Be $false
  }

  It 'does not treat the declared version as a regex (issue #74''s own example)' {
    Test-UnityEditorInstalled -Installed @('2022X3Y22f1') -Target '2022.3.22f1' | Should -Be $false
  }

  It 'returns $false against an empty Installed list' {
    Test-UnityEditorInstalled -Installed @() -Target '2022.3.22f1' | Should -Be $false
  }
}

Describe 'Get-UnityEditorDrift' {
  It 'reports nothing when declared and installed match exactly' {
    $drift = Get-UnityEditorDrift -Declared @('2022.3.22f1') -Installed @('2022.3.22f1')

    $drift.MissingVersions | Should -BeNullOrEmpty
    $drift.ExtraVersions | Should -BeNullOrEmpty
  }

  It 'reports a declared version that is not installed as missing' {
    $drift = Get-UnityEditorDrift -Declared @('2022.3.22f1') -Installed @()

    $drift.MissingVersions | Should -Be @('2022.3.22f1')
  }

  It 'reports an installed version that is not declared as extra, without removing it' {
    $drift = Get-UnityEditorDrift -Declared @('2022.3.22f1') -Installed @('2022.3.22f1', '2021.1.1f1')

    $drift.ExtraVersions | Should -Be @('2021.1.1f1')
    $drift.MissingVersions | Should -BeNullOrEmpty
  }
}

Describe 'Invoke-UnityEditorInstall' {
  It 'returns 0 on success' {
    Mock Invoke-UnityInstallCommand { 0 }

    Invoke-UnityEditorInstall -Version '2022.3.22f1' -Changeset '887be4894c44' -Modules @('android') | Should -Be 0
  }

  It 'passes -m for each declared module plus --cm' {
    Mock Invoke-UnityInstallCommand { 0 }

    Invoke-UnityEditorInstall -Version '2022.3.22f1' -Changeset '887be4894c44' -Modules @('android', 'ios') | Out-Null

    Should -Invoke Invoke-UnityInstallCommand -Times 1 -ParameterFilter {
      ($ArgumentList -join ' ') -eq 'install 2022.3.22f1 -c 887be4894c44 -m android -m ios --cm'
    }
  }

  It 'passes --cm with no -m flags when no modules are declared' {
    Mock Invoke-UnityInstallCommand { 0 }

    Invoke-UnityEditorInstall -Version '2022.3.22f1' -Changeset '887be4894c44' | Out-Null

    Should -Invoke Invoke-UnityInstallCommand -Times 1 -ParameterFilter {
      ($ArgumentList -join ' ') -eq 'install 2022.3.22f1 -c 887be4894c44 --cm'
    }
  }

  It 'returns 130 and writes a distinct error when interrupted' {
    Mock Invoke-UnityInstallCommand { 130 }

    $exitCode = Invoke-UnityEditorInstall -Version '2022.3.22f1' -Changeset '887be4894c44' -ErrorAction SilentlyContinue
    $exitCode | Should -Be 130
  }

  It 'returns a non-zero, non-130 exit code without throwing' {
    Mock Invoke-UnityInstallCommand { 6 }

    $exitCode = Invoke-UnityEditorInstall -Version '2022.3.22f1' -Changeset '887be4894c44' -ErrorAction SilentlyContinue
    $exitCode | Should -Be 6
  }
}

Describe 'Sync-UnityEditor' {
  BeforeAll {
    $script:configPath = Join-Path -Path $TestDrive -ChildPath 'runtime-versions.psd1'
    Set-Content -Path $script:configPath -Value @'
@{
  Unity = @{
    Version   = '2022.3.22f1'
    Changeset = '887be4894c44'
    Modules   = @('android', 'documentation')
  }
}
'@
  }

  It 'stops with an explicit error and does not check installed editors when the Unity CLI is unavailable' {
    Mock Test-UnityCliAvailable { $false }
    Mock Get-InstalledUnityEditors { @() }
    Mock Invoke-UnityEditorInstall { 0 }

    { Sync-UnityEditor -ConfigPath $script:configPath -ErrorAction SilentlyContinue } | Should -Not -Throw

    Should -Invoke Get-InstalledUnityEditors -Times 0
    Should -Invoke Invoke-UnityEditorInstall -Times 0
  }

  It 'aborts without attempting an install when the installed-editors list cannot be determined' {
    Mock Test-UnityCliAvailable { $true }
    Mock Get-InstalledUnityEditors { throw 'unity editors -i --format json failed' }
    Mock Invoke-UnityEditorInstall { 0 }

    { Sync-UnityEditor -ConfigPath $script:configPath -ErrorAction SilentlyContinue } | Should -Not -Throw

    Should -Invoke Invoke-UnityEditorInstall -Times 0
  }

  It 'skips installation when the declared version is already installed' {
    Mock Test-UnityCliAvailable { $true }
    Mock Get-InstalledUnityEditors { @('2022.3.22f1') }
    Mock Invoke-UnityEditorInstall { 0 }

    Sync-UnityEditor -ConfigPath $script:configPath

    Should -Invoke Invoke-UnityEditorInstall -Times 0
  }

  It 'installs when the declared version is missing, then does not reinstall on a second run (idempotent)' {
    Mock Test-UnityCliAvailable { $true }
    $script:installed = @()
    Mock Get-InstalledUnityEditors { $script:installed }
    Mock Invoke-UnityEditorInstall {
      $script:installed = @('2022.3.22f1')
      return 0
    }

    Sync-UnityEditor -ConfigPath $script:configPath
    Should -Invoke Invoke-UnityEditorInstall -Times 1

    Sync-UnityEditor -ConfigPath $script:configPath
    Should -Invoke Invoke-UnityEditorInstall -Times 1
  }

  It 'reports an installed-but-undeclared version without attempting to remove it' {
    Mock Test-UnityCliAvailable { $true }
    Mock Get-InstalledUnityEditors { @('2022.3.22f1', '2021.1.1f1') }
    Mock Invoke-UnityEditorInstall { 0 }
    Mock Remove-Item { }

    Sync-UnityEditor -ConfigPath $script:configPath

    Should -Invoke Invoke-UnityEditorInstall -Times 0
    Should -Invoke Remove-Item -Times 0
  }

  It 'writes a non-terminating error and does not throw when the config file is missing' {
    { Sync-UnityEditor -ConfigPath (Join-Path $TestDrive 'does-not-exist.psd1') -ErrorAction SilentlyContinue } | Should -Not -Throw
  }

  It 'writes a non-terminating error and does not throw when the Unity entry is missing' {
    $path = Join-Path -Path $TestDrive -ChildPath 'no-unity.psd1'
    Set-Content -Path $path -Value "@{ Node = @{} }"

    { Sync-UnityEditor -ConfigPath $path -ErrorAction SilentlyContinue } | Should -Not -Throw
  }

  It 'writes a non-terminating error and does not throw when Unity is missing Modules' {
    $path = Join-Path -Path $TestDrive -ChildPath 'incomplete-unity.psd1'
    Set-Content -Path $path -Value "@{ Unity = @{ Version = '2022.3.22f1'; Changeset = '887be4894c44' } }"

    { Sync-UnityEditor -ConfigPath $path -ErrorAction SilentlyContinue } | Should -Not -Throw
  }
}
