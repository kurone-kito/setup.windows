BeforeAll {
  . (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'libs', 'pwsh-installer.ps1')
}

Describe 'Get-PwshInstallArguments' {
  It 'requests a machine-scope install' {
    $arguments = Get-PwshInstallArguments

    ($arguments -join ' ') | Should -Match '--scope machine'
  }

  It 'forces the WiX/MSI installer type over the MSIX bundle winget would otherwise prefer' {
    $arguments = Get-PwshInstallArguments

    ($arguments -join ' ') | Should -Match '--installer-type wix'
  }

  It 'targets the Microsoft.PowerShell winget package' {
    $arguments = Get-PwshInstallArguments

    ($arguments -join ' ') | Should -Match '--id Microsoft\.PowerShell'
  }

  It 'does not pass --version (winget install requires an exact version string, not a wildcard/range)' {
    $arguments = Get-PwshInstallArguments

    $arguments | Should -Not -Contain '--version'
  }
}

Describe 'Test-PwshUserScopeCoexistence' {
  It 'returns $false without checking the filesystem when AliasPath is null or empty' {
    Mock Test-Path { throw 'Test-Path should not be called when AliasPath is empty' }

    Test-PwshUserScopeCoexistence -AliasPath $null | Should -Be $false
    Test-PwshUserScopeCoexistence -AliasPath '' | Should -Be $false
  }

  It 'returns $true when the user-scope MSIX execution alias exists' {
    Mock Test-Path { $true }

    Test-PwshUserScopeCoexistence -AliasPath '/fake/Microsoft/WindowsApps/pwsh.exe' | Should -Be $true
  }

  It 'returns $false when the user-scope MSIX execution alias does not exist' {
    Mock Test-Path { $false }

    Test-PwshUserScopeCoexistence -AliasPath '/fake/Microsoft/WindowsApps/pwsh.exe' | Should -Be $false
  }
}

Describe 'Test-PwshMachineScopeInstalled' {
  It 'returns $false without checking the filesystem when ExePath is null or empty' {
    Mock Test-Path { throw 'Test-Path should not be called when ExePath is empty' }

    Test-PwshMachineScopeInstalled -ExePath $null | Should -Be $false
    Test-PwshMachineScopeInstalled -ExePath '' | Should -Be $false
  }

  It 'returns $true when the machine-scope pwsh.exe exists' {
    Mock Test-Path { $true }

    Test-PwshMachineScopeInstalled -ExePath '/fake/Program Files/PowerShell/7/pwsh.exe' | Should -Be $true
  }

  It 'returns $false when the machine-scope pwsh.exe does not exist' {
    Mock Test-Path { $false }

    Test-PwshMachineScopeInstalled -ExePath '/fake/Program Files/PowerShell/7/pwsh.exe' | Should -Be $false
  }
}

Describe 'Sync-Pwsh' {
  BeforeEach {
    Mock Test-PwshUserScopeCoexistence { $false }
    Mock Test-PwshMachineScopeInstalled { $true }
  }

  It 'installs with the machine-scope argument list' {
    $script:capturedArgumentList = $null
    Mock Invoke-PwshInstallCommand {
      $script:capturedArgumentList = $ArgumentList
      0
    }

    Sync-Pwsh

    ($script:capturedArgumentList -join ' ') | Should -Match '--scope machine'
  }

  It 'writes a non-terminating error and does not throw when the installer exits non-zero' {
    Mock Invoke-PwshInstallCommand { 1 }

    { Sync-Pwsh -ErrorAction SilentlyContinue } | Should -Not -Throw
  }

  It 'still checks for user-scope MSIX coexistence when the installer fails' {
    Mock Invoke-PwshInstallCommand { 1 }

    Sync-Pwsh -ErrorAction SilentlyContinue

    Should -Invoke Test-PwshUserScopeCoexistence -Times 1
  }

  It 'checks for user-scope MSIX coexistence after a successful install too' {
    Mock Invoke-PwshInstallCommand { 0 }

    Sync-Pwsh

    Should -Invoke Test-PwshUserScopeCoexistence -Times 1
  }

  It 'warns when a user-scope MSIX execution alias coexists after a verified successful install, without throwing' {
    Mock Invoke-PwshInstallCommand { 0 }
    Mock Test-PwshUserScopeCoexistence { $true }

    { Sync-Pwsh -WarningAction SilentlyContinue } | Should -Not -Throw
  }

  It 'does not warn when no user-scope MSIX execution alias is present' {
    Mock Invoke-PwshInstallCommand { 0 }

    $warnings = Sync-Pwsh 3>&1 | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

    $warnings | Should -BeNullOrEmpty
  }

  It 'correlates a failed install with a coexisting user-scope MSIX alias in the error message' {
    Mock Invoke-PwshInstallCommand { 1 }
    Mock Test-PwshUserScopeCoexistence { $true }

    Sync-Pwsh -ErrorAction SilentlyContinue -ErrorVariable syncErrors 2>&1 | Out-Null
    $syncErrors.Count | Should -Be 1
    $syncErrors[0].ToString() | Should -Match 'installer technology'
  }

  It 'does not mention MSIX coexistence in the error message when no alias is present' {
    Mock Invoke-PwshInstallCommand { 1 }
    Mock Test-PwshUserScopeCoexistence { $false }

    Sync-Pwsh -ErrorAction SilentlyContinue -ErrorVariable syncErrors 2>&1 | Out-Null
    $syncErrors.Count | Should -Be 1
    $syncErrors[0].ToString() | Should -Not -Match 'installer technology'
  }

  It 'treats a verified-missing machine-scope binary as a failure even when winget exits 0' {
    Mock Invoke-PwshInstallCommand { 0 }
    Mock Test-PwshMachineScopeInstalled { $false }

    { Sync-Pwsh -ErrorAction SilentlyContinue } | Should -Not -Throw
    Sync-Pwsh -ErrorAction SilentlyContinue -ErrorVariable syncErrors 2>&1 | Out-Null
    $syncErrors.Count | Should -Be 1
    $syncErrors[0].ToString() | Should -Match 'not found at the expected machine-scope path'
  }

  It 'does not print the success message when the machine-scope binary verification fails' {
    Mock Invoke-PwshInstallCommand { 0 }
    Mock Test-PwshMachineScopeInstalled { $false }

    $output = Sync-Pwsh -ErrorAction SilentlyContinue 6>&1 | Out-String

    $output | Should -Not -Match 'installation complete'
  }
}
