BeforeAll {
  Import-Module powershell-yaml

  . (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'libs', 'configuration-builder.ps1')

  # A small fixture standing in for configurations/*.dsc.yaml -- not the
  # real 137-resource file, so these tests stay fast and don't churn
  # every time a package is added to the real configuration.
  $script:fixtureYaml = @'
properties:
  resources:
    - resource: Microsoft.WinGet.DSC/WinGetPackage
      id: pkg.alpha
      directives:
        description: Alpha package
      settings:
        id: Vendor.Alpha
        source: winget
    - resource: Microsoft.WinGet.DSC/WinGetPackage
      id: pkg.beta
      directives:
        description: Beta package
      settings:
        id: Vendor.Beta
        source: winget
    - resource: Microsoft.WinGet.DSC/WinGetPackage
      id: pkg.gamma
      directives:
        description: Gamma package
      settings:
        id: XXXXXXXXXXXX
        source: msstore
    - resource: PSDscResources/Registry
      id: test.registryValue
      directives:
        description: A registry tweak not expressible in import.json
      settings:
        Key: 'HKCU:\Software\Test'
        ValueName: Test
        ValueType: Dword
        ValueData: '1'
        Ensure: Present
  assertions:
    - resource: Microsoft.Windows.Developer/OsVersion
      directives:
        description: Require a minimum OS version
      settings:
        MinVersion: 10.0.19045
'@

  $script:sourceDetail = [ordered]@{
    winget  = [ordered]@{ Argument = 'https://cdn.winget.microsoft.com/cache'; Identifier = 'Microsoft.Winget.Source_8wekyb3d8bbwe'; Name = 'winget'; Type = 'Microsoft.PreIndexed.Package' }
    msstore = [ordered]@{ Argument = 'https://storeedgefd.dsx.mp.microsoft.com/v9.0'; Identifier = 'StoreEdgeFD'; Name = 'msstore'; Type = 'Microsoft.Rest' }
  }

  function script:New-FixtureSplit {
    $document = ConvertFrom-Yaml -Yaml $script:fixtureYaml -Ordered
    Split-DscResource -Resource @($document['properties']['resources']) -Assertion @($document['properties']['assertions'])
  }
}

Describe 'Split-DscResource' {
  Context 'source grouping' {
    It 'groups WinGetPackage settings.id by settings.source in first-encounter order' {
      $split = New-FixtureSplit

      @($split.Grouped.Keys) | Should -Be @('winget', 'msstore')
      @($split.Grouped['winget']) | Should -Be @('Vendor.Alpha', 'Vendor.Beta')
      @($split.Grouped['msstore']) | Should -Be @('XXXXXXXXXXXX')
    }
  }

  Context 'WinGetPackage vs. other-resource routing' {
    It 'routes non-WinGetPackage resources and assertions into Unapplied, not Grouped' {
      $split = New-FixtureSplit

      $split.Unapplied.Count | Should -Be 2

      $split.Unapplied[0].Resource | Should -Be 'PSDscResources/Registry'
      $split.Unapplied[0].Id | Should -Be 'test.registryValue'
      $split.Unapplied[0].Description | Should -Be 'A registry tweak not expressible in import.json'

      $split.Unapplied[1].Resource | Should -Be 'Microsoft.Windows.Developer/OsVersion'
      $split.Unapplied[1].Id | Should -BeNullOrEmpty
      $split.Unapplied[1].Description | Should -Be 'Require a minimum OS version'
    }

    It 'never places a WinGetPackage resource in Unapplied' {
      $split = New-FixtureSplit

      $split.Unapplied.Resource | Should -Not -Contain 'Microsoft.WinGet.DSC/WinGetPackage'
    }
  }
}

Describe 'ConvertTo-PackagesImportJson' {
  It 'renders each source group with its matching SourceDetails, in schema 2.0 shape' {
    $split = New-FixtureSplit

    $parsed = ConvertTo-PackagesImportJson -Grouped $split.Grouped -SourceDetail $script:sourceDetail | ConvertFrom-Json

    $parsed.'$schema' | Should -Be 'https://aka.ms/winget-packages.schema.2.0.json'
    $parsed.Sources.Count | Should -Be 2
    $parsed.Sources[0].SourceDetails.Name | Should -Be 'winget'
    @($parsed.Sources[0].Packages.PackageIdentifier) | Should -Be @('Vendor.Alpha', 'Vendor.Beta')
    $parsed.Sources[1].SourceDetails.Name | Should -Be 'msstore'
    @($parsed.Sources[1].Packages.PackageIdentifier) | Should -Be @('XXXXXXXXXXXX')
  }

  It 'throws when a grouped source has no matching SourceDetails entry' {
    $split = New-FixtureSplit
    $incomplete = [ordered]@{ winget = $script:sourceDetail.winget }

    { ConvertTo-PackagesImportJson -Grouped $split.Grouped -SourceDetail $incomplete } | Should -Throw
  }
}

Describe 'ConvertTo-UnappliedResourceJson' {
  It 'renders the unapplied list as a JSON array' {
    $split = New-FixtureSplit

    $parsed = ConvertTo-UnappliedResourceJson -Unapplied $split.Unapplied | ConvertFrom-Json

    @($parsed).Count | Should -Be 2
  }

  It 'renders a single entry as a one-element JSON array, not a bare object' {
    $split = New-FixtureSplit

    $json = ConvertTo-UnappliedResourceJson -Unapplied @($split.Unapplied[0])

    $json.TrimStart() | Should -Match '^\['
  }
}

Describe 'output determinism' {
  It 'produces byte-identical import.json and unapplied.json text across repeated runs on the same input' {
    $split1 = New-FixtureSplit
    $split2 = New-FixtureSplit

    $import1 = ConvertTo-PackagesImportJson -Grouped $split1.Grouped -SourceDetail $script:sourceDetail
    $import2 = ConvertTo-PackagesImportJson -Grouped $split2.Grouped -SourceDetail $script:sourceDetail
    $unapplied1 = ConvertTo-UnappliedResourceJson -Unapplied $split1.Unapplied
    $unapplied2 = ConvertTo-UnappliedResourceJson -Unapplied $split2.Unapplied

    ($import1 -ceq $import2) | Should -BeTrue
    ($unapplied1 -ceq $unapplied2) | Should -BeTrue
  }
}
