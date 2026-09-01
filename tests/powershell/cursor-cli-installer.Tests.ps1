BeforeAll {
  . (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'libs', 'cursor-cli-installer.ps1')
}

Describe 'Add-CursorCliToProcessPath' {
  BeforeEach {
    $script:originalPath = $env:Path
  }

  AfterEach {
    $env:Path = $script:originalPath
  }

  It 'appends the install dir when not already present' {
    $env:Path = '/existing/one;/existing/two'

    Add-CursorCliToProcessPath -InstallDir '/cursor-agent/versions'

    $env:Path | Should -Match ([regex]::Escape('/cursor-agent/versions'))
  }

  It 'does not duplicate an entry that only differs by case or a trailing slash' {
    $env:Path = '/Existing/CURSOR-AGENT/VERSIONS/;/existing/two'

    Add-CursorCliToProcessPath -InstallDir '/existing/cursor-agent/versions'

    ($env:Path -split ';' | Where-Object { $_ -ne '' }).Count | Should -Be 2
  }

  It 'no-ops instead of throwing when InstallDir is null or empty' {
    $env:Path = '/existing/one'

    { Add-CursorCliToProcessPath -InstallDir $null } | Should -Not -Throw
    { Add-CursorCliToProcessPath -InstallDir '' } | Should -Not -Throw
    $env:Path | Should -Be '/existing/one'
  }

  It 'removes pre-existing duplicate entries, keeping the first occurrence in place' {
    $env:Path = '/existing/one;/cursor-agent/versions;/existing/two;/CURSOR-AGENT/VERSIONS/;/existing/three'

    Add-CursorCliToProcessPath -InstallDir '/cursor-agent/versions'

    $env:Path | Should -Be '/existing/one;/cursor-agent/versions;/existing/two;/existing/three'
  }
}

Describe 'Invoke-CursorCliInstaller' {
  It 'returns a non-zero exit code instead of throwing when the download fails' {
    Mock Invoke-WebRequest { throw [System.Net.WebException]::new('Name or service not known') }
    Mock Start-Process { }

    $exitCode = Invoke-CursorCliInstaller -ErrorAction SilentlyContinue
    $exitCode | Should -Be 1

    Should -Invoke Start-Process -Times 0
  }

  It 'removes the temp script even when the download fails' {
    Mock Invoke-WebRequest { throw [System.Net.WebException]::new('Name or service not known') }
    Mock Start-Process { }
    Mock Remove-Item { }

    Invoke-CursorCliInstaller -ErrorAction SilentlyContinue | Out-Null

    Should -Invoke Remove-Item -Times 1
  }

  It 'returns the child process exit code on success' {
    Mock Invoke-WebRequest { }
    Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }

    Invoke-CursorCliInstaller | Should -Be 0
  }

  It 'removes the temp script after a successful install too' {
    Mock Invoke-WebRequest { }
    Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }
    Mock Remove-Item { }

    Invoke-CursorCliInstaller | Out-Null

    Should -Invoke Remove-Item -Times 1
  }

  It 'quotes the -File argument so a TEMP path containing spaces is not truncated by Start-Process argument joining' {
    $script:capturedArgumentList = $null
    Mock Invoke-WebRequest { }
    Mock Start-Process {
      $script:capturedArgumentList = $ArgumentList
      [pscustomobject]@{ ExitCode = 0 }
    }

    Invoke-CursorCliInstaller | Out-Null

    $fileIndex = [array]::IndexOf($script:capturedArgumentList, '-File')
    $fileIndex | Should -BeGreaterThan -1
    $script:capturedArgumentList[$fileIndex + 1] | Should -Match '^".*"$'
  }
}

Describe 'Sync-CursorCli' {
  It 'installs on every call, with no prerequisite command check gating it' {
    Mock Add-CursorCliToProcessPath { }
    Mock Invoke-CursorCliInstaller { 0 }

    Sync-CursorCli
    Sync-CursorCli

    Should -Invoke Invoke-CursorCliInstaller -Times 2
  }

  It 'adds the install dir to PATH both before and after a successful install' {
    Mock Add-CursorCliToProcessPath { }
    Mock Invoke-CursorCliInstaller { 0 }

    Sync-CursorCli

    Should -Invoke Add-CursorCliToProcessPath -Times 2
  }

  It 'writes a non-terminating error and does not throw when the installer exits non-zero' {
    Mock Add-CursorCliToProcessPath { }
    Mock Invoke-CursorCliInstaller { 1 }

    { Sync-CursorCli -ErrorAction SilentlyContinue } | Should -Not -Throw
  }

  It 'does not add the install dir to PATH a second time when the installer fails' {
    Mock Add-CursorCliToProcessPath { }
    Mock Invoke-CursorCliInstaller { 1 }

    Sync-CursorCli -ErrorAction SilentlyContinue

    Should -Invoke Add-CursorCliToProcessPath -Times 1
  }
}
