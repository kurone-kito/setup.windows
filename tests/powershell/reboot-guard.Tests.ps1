BeforeAll {
  . (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'libs', 'reboot-guard.ps1')
}

Describe 'Test-PendingRebootIndicators' {
  BeforeEach {
    # HKLM: does not exist on the Linux runner this suite also runs on, so
    # every registry-reading cmdlet must be mocked -- these filterless
    # defaults stand in for "nothing pending" unless a test below
    # overrides one path with a -ParameterFilter-scoped Mock.
    Mock Test-Path { $false }
    Mock Get-ItemProperty { $null }
  }

  It 'returns all-false when no indicator is pending' {
    $result = Test-PendingRebootIndicators

    $result.ComponentBasedServicing | Should -BeFalse
    $result.WindowsUpdateAutoUpdate | Should -BeFalse
    $result.PendingFileRenameOperations | Should -BeFalse
    $result.ComputerRenamePending | Should -BeFalse
  }

  It 'detects ComponentBasedServicing alone' {
    Mock Test-Path { $true } -ParameterFilter {
      $Path -eq 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    }

    $result = Test-PendingRebootIndicators

    $result.ComponentBasedServicing | Should -BeTrue
    $result.WindowsUpdateAutoUpdate | Should -BeFalse
    $result.PendingFileRenameOperations | Should -BeFalse
    $result.ComputerRenamePending | Should -BeFalse
    Should -Invoke Test-Path -Times 1 -ParameterFilter {
      $Path -eq 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    }
  }

  It 'detects WindowsUpdateAutoUpdate alone' {
    Mock Test-Path { $true } -ParameterFilter {
      $Path -eq 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    }

    $result = Test-PendingRebootIndicators

    $result.ComponentBasedServicing | Should -BeFalse
    $result.WindowsUpdateAutoUpdate | Should -BeTrue
    $result.PendingFileRenameOperations | Should -BeFalse
    $result.ComputerRenamePending | Should -BeFalse
    Should -Invoke Test-Path -Times 1 -ParameterFilter {
      $Path -eq 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    }
  }

  It 'detects PendingFileRenameOperations alone' {
    Mock Get-ItemProperty {
      [pscustomobject]@{ PendingFileRenameOperations = @('C:\old.dll', 'C:\old.dll.tmp') }
    } -ParameterFilter {
      $Path -eq 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -and $Name -eq 'PendingFileRenameOperations'
    }

    $result = Test-PendingRebootIndicators

    $result.ComponentBasedServicing | Should -BeFalse
    $result.WindowsUpdateAutoUpdate | Should -BeFalse
    $result.PendingFileRenameOperations | Should -BeTrue
    $result.ComputerRenamePending | Should -BeFalse
    Should -Invoke Get-ItemProperty -Times 1 -ParameterFilter {
      $Path -eq 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -and $Name -eq 'PendingFileRenameOperations'
    }
  }

  It 'treats a single-empty-string PendingFileRenameOperations value as not pending' {
    # Boxstarter's own Get-PendingReboot has the same blind spot: a
    # REG_MULTI_SZ holding one empty string is falsy via plain `if
    # ($value)`, matching the check this function uses.
    Mock Get-ItemProperty {
      [pscustomobject]@{ PendingFileRenameOperations = @('') }
    } -ParameterFilter {
      $Path -eq 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -and $Name -eq 'PendingFileRenameOperations'
    }

    $result = Test-PendingRebootIndicators

    $result.PendingFileRenameOperations | Should -BeFalse
  }

  It 'detects ComputerRenamePending via an ActiveComputerName/ComputerName mismatch' {
    Mock Get-ItemProperty {
      [pscustomobject]@{ ComputerName = 'OLD-NAME' }
    } -ParameterFilter {
      $Path -eq 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' -and $Name -eq 'ComputerName'
    }
    Mock Get-ItemProperty {
      [pscustomobject]@{ ComputerName = 'NEW-NAME' }
    } -ParameterFilter {
      $Path -eq 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -and $Name -eq 'ComputerName'
    }

    $result = Test-PendingRebootIndicators

    $result.ComponentBasedServicing | Should -BeFalse
    $result.WindowsUpdateAutoUpdate | Should -BeFalse
    $result.PendingFileRenameOperations | Should -BeFalse
    $result.ComputerRenamePending | Should -BeTrue
  }

  It 'detects ComputerRenamePending via a pending domain join key' {
    Mock Test-Path { $true } -ParameterFilter {
      $Path -eq 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\JoinDomain'
    }

    $result = Test-PendingRebootIndicators

    $result.ComputerRenamePending | Should -BeTrue
    Should -Invoke Test-Path -Times 1 -ParameterFilter {
      $Path -eq 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\JoinDomain'
    }
  }

  It 'detects multiple indicators simultaneously' {
    Mock Test-Path { $true } -ParameterFilter {
      $Path -eq 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    }
    Mock Test-Path { $true } -ParameterFilter {
      $Path -eq 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    }
    Mock Get-ItemProperty {
      [pscustomobject]@{ PendingFileRenameOperations = @('C:\old.dll') }
    } -ParameterFilter {
      $Path -eq 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -and $Name -eq 'PendingFileRenameOperations'
    }
    Mock Test-Path { $true } -ParameterFilter {
      $Path -eq 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\AvoidSpnSet'
    }

    $result = Test-PendingRebootIndicators

    $result.ComponentBasedServicing | Should -BeTrue
    $result.WindowsUpdateAutoUpdate | Should -BeTrue
    $result.PendingFileRenameOperations | Should -BeTrue
    $result.ComputerRenamePending | Should -BeTrue
  }
}
