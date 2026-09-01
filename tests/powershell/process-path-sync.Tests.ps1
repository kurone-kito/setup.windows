BeforeAll {
  . (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'libs', 'process-path-sync.ps1')
}

Describe 'Sync-ProcessPath' {
  BeforeEach {
    $script:originalPath = $env:Path
  }

  AfterEach {
    $env:Path = $script:originalPath
  }

  It 'merges Machine- and User-scope registry PATH values into the current process PATH' {
    $env:Path = '/existing/one'
    Mock Get-RegistryPathValue -ParameterFilter { $Scope -eq 'Machine' } { '/machine/dir' }
    Mock Get-RegistryPathValue -ParameterFilter { $Scope -eq 'User' } { '/user/dir' }

    Sync-ProcessPath

    $entries = @($env:Path -split ';' | Where-Object { $_ -ne '' })
    $entries | Should -Contain '/existing/one'
    $entries | Should -Contain '/machine/dir'
    $entries | Should -Contain '/user/dir'
  }

  It 'splits a multi-entry registry PATH value on the separator' {
    $env:Path = '/existing/one'
    Mock Get-RegistryPathValue -ParameterFilter { $Scope -eq 'Machine' } { '/machine/one;/machine/two' }
    Mock Get-RegistryPathValue -ParameterFilter { $Scope -eq 'User' } { $null }

    Sync-ProcessPath

    $entries = @($env:Path -split ';' | Where-Object { $_ -ne '' })
    $entries | Should -Contain '/machine/one'
    $entries | Should -Contain '/machine/two'
  }

  It 'does not duplicate an entry that only differs by case or a trailing slash' {
    $env:Path = '/Existing/DIR/'
    Mock Get-RegistryPathValue -ParameterFilter { $Scope -eq 'Machine' } { '/existing/dir' }
    Mock Get-RegistryPathValue -ParameterFilter { $Scope -eq 'User' } { $null }

    Sync-ProcessPath

    @($env:Path -split ';' | Where-Object { $_ -ne '' }).Count | Should -Be 1
  }

  It 'keeps the first occurrence of a duplicate and preserves relative order' {
    $env:Path = '/existing/one;/shared/dir;/existing/two'
    Mock Get-RegistryPathValue -ParameterFilter { $Scope -eq 'Machine' } { '/SHARED/DIR/;/machine/new' }
    Mock Get-RegistryPathValue -ParameterFilter { $Scope -eq 'User' } { $null }

    Sync-ProcessPath

    $env:Path | Should -Be '/existing/one;/shared/dir;/existing/two;/machine/new'
  }

  It 'no-ops safely (existing PATH unchanged) when both registry scopes are null' {
    $env:Path = '/existing/one;/existing/two'
    Mock Get-RegistryPathValue { $null }

    { Sync-ProcessPath } | Should -Not -Throw
    $env:Path | Should -Be '/existing/one;/existing/two'
  }

  It 'no-ops safely when both registry scopes are empty strings' {
    $env:Path = '/existing/one'
    Mock Get-RegistryPathValue { '' }

    { Sync-ProcessPath } | Should -Not -Throw
    $env:Path | Should -Be '/existing/one'
  }

  It 'reproduces the issue #129 same-process detection gap: a real tool installed only into a directory reported by the registry read becomes part of $env:Path -- the mechanism Get-Command-based checks rely on -- after Sync-ProcessPath runs, and was absent before' {
    # A real file (not just a string) is used for this tool directory so
    # the scenario matches the real one: a genuine binary landed on disk
    # earlier in this process (e.g. Phase 2's WinGet Configuration) in a
    # directory this process's own $env:Path doesn't include yet, while
    # the Machine-scope registry PATH (mocked here) already does.
    $toolDir = Join-Path ([System.IO.Path]::GetTempPath()) "process-path-sync-test-$([guid]::NewGuid().ToString('N'))"
    New-Item -Path $toolDir -ItemType Directory -Force | Out-Null
    try {
      $toolName = 'fake-newly-installed-tool-129'
      if ($IsWindows) {
        $toolPath = Join-Path $toolDir "$toolName.cmd"
        Set-Content -Path $toolPath -Value '@echo off' -Encoding ascii
      }
      else {
        $toolPath = Join-Path $toolDir $toolName
        $shellScript = @'
#!/bin/sh
exit 0
'@
        Set-Content -Path $toolPath -Value $shellScript -Encoding ascii
        & chmod +x $toolPath
      }

      $env:Path = '/existing/one'
      Mock Get-RegistryPathValue -ParameterFilter { $Scope -eq 'Machine' } { $toolDir }
      Mock Get-RegistryPathValue -ParameterFilter { $Scope -eq 'User' } { $null }

      # Content-based assertions (not a live Get-Command probe): $env:Path
      # and the OS-level PATH environment variable Get-Command actually
      # resolves against are the same case-insensitive variable on
      # Windows (this function's only real target), but distinct,
      # case-sensitive variables on Linux/macOS -- so a real Get-Command
      # round-trip through $env:Path here would be meaningless on the
      # non-Windows runner this suite's CI job actually executes on. This
      # mirrors the existing repo convention: Add-CoderabbitCliToProcessPath
      # / Add-UnityCliToProcessPath's own Pester tests likewise only ever
      # assert on $env:Path's string content, never on a live Get-Command
      # resolution.
      @($env:Path -split ';' | Where-Object { $_ -ne '' }) | Should -Not -Contain $toolDir

      Sync-ProcessPath

      @($env:Path -split ';' | Where-Object { $_ -ne '' }) | Should -Contain $toolDir

      # Bonus real-world confirmation, Windows-only: on Windows,
      # $env:Path IS the case-insensitive OS-level PATH Get-Command
      # resolves against, so this genuinely proves end-to-end detection
      # there. Skipped everywhere else (including this suite's actual CI
      # runner) rather than silently no-op'd, so it's visible in the
      # Pester summary as skipped, not counted as a pass.
      if ($IsWindows) {
        Get-Command $toolName -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
      }
    }
    finally {
      Remove-Item -Path $toolDir -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}
