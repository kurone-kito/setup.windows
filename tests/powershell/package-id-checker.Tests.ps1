BeforeAll {
  . (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'libs', 'package-id-checker.ps1')
}

Describe 'Test-PackageExistence' {
  Context 'classification by exit code' {
    It 'classifies exit 0 as Confirmed' {
      Mock Invoke-WingetShow { 0 }

      $result = Test-PackageExistence -Id 'Vendor.Good' -Source 'winget'

      $result.Status | Should -Be 'Confirmed'
      $result.ExitCode | Should -Be 0
    }

    It 'classifies the winget-cli NO_APPLICATIONS_FOUND exit code as NotFound' {
      Mock Invoke-WingetShow { -1978335212 }

      $result = Test-PackageExistence -Id 'Vendor.Bad' -Source 'winget'

      $result.Status | Should -Be 'NotFound'
      $result.ExitCode | Should -Be -1978335212
    }

    It 'classifies any other non-zero exit code as Indeterminate, not NotFound' -ForEach @(
      @{ Description = 'source-open failure'; ExitCode = -1978335163 }
      @{ Description = 'an unrecognized error'; ExitCode = 1 }
    ) {
      Mock Invoke-WingetShow { $ExitCode }

      $result = Test-PackageExistence -Id 'Vendor.Unclear' -Source 'winget'

      $result.Status | Should -Be 'Indeterminate'
      $result.ExitCode | Should -Be $ExitCode
    }
  }
}

Describe 'Test-PackageIdList' {
  It 'buckets Confirmed, NotFound, and Indeterminate separately across a Grouped map' {
    Mock Invoke-WingetShow {
      switch ($Id) {
        'Vendor.Good1' { 0 }
        'Vendor.Good2' { 0 }
        'Vendor.Bad' { -1978335212 }
        'Vendor.Unclear' { -1978335163 }
      }
    }

    $grouped = [ordered]@{
      winget  = @('Vendor.Good1', 'Vendor.Bad')
      msstore = @('Vendor.Good2', 'Vendor.Unclear')
    }

    $result = Test-PackageIdList -Grouped $grouped

    $result.Confirmed.Count | Should -Be 2
    $result.NotFound.Count | Should -Be 1
    $result.NotFound[0].Id | Should -Be 'Vendor.Bad'
    $result.Indeterminate.Count | Should -Be 1
    $result.Indeterminate[0].Id | Should -Be 'Vendor.Unclear'
    Should -Invoke Invoke-WingetShow -Times 4
  }
}

Describe 'Get-PackageIdCheckExitCode' {
  It 'returns 0 when everything is Confirmed' {
    $result = [ordered]@{ Confirmed = @(1); NotFound = @(); Indeterminate = @() }

    Get-PackageIdCheckExitCode -Result $result | Should -Be 0
  }

  It 'returns 1 when at least one id is NotFound' {
    $result = [ordered]@{ Confirmed = @(); NotFound = @(1); Indeterminate = @() }

    Get-PackageIdCheckExitCode -Result $result | Should -Be 1
  }

  It 'returns 2, distinct from NotFound''s 1, when only Indeterminate ids occurred' {
    $result = [ordered]@{ Confirmed = @(); NotFound = @(); Indeterminate = @(1) }

    Get-PackageIdCheckExitCode -Result $result | Should -Be 2
  }

  It 'returns 1 (NotFound takes priority) when both NotFound and Indeterminate occurred' {
    $result = [ordered]@{ Confirmed = @(); NotFound = @(1); Indeterminate = @(1) }

    Get-PackageIdCheckExitCode -Result $result | Should -Be 1
  }
}
