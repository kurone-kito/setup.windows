BeforeAll {
  . (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'libs', 'runtime-versions.ps1')
}

Describe 'Get-RuntimeVersionsConfig' {
  It 'returns the parsed hashtable for a valid file' {
    $path = Join-Path -Path $TestDrive -ChildPath 'valid.psd1'
    Set-Content -Path $path -Value "@{ Foo = 'bar' }"

    $result = Get-RuntimeVersionsConfig -Path $path

    $result.Foo | Should -Be 'bar'
  }

  It 'returns $null, not a thrown error, when the file does not exist' {
    $path = Join-Path -Path $TestDrive -ChildPath 'missing.psd1'

    $result = Get-RuntimeVersionsConfig -Path $path -ErrorAction SilentlyContinue

    $result | Should -BeNullOrEmpty
  }

  It 'returns $null, not a thrown error, when the file is not valid PowerShell data' {
    $path = Join-Path -Path $TestDrive -ChildPath 'malformed.psd1'
    Set-Content -Path $path -Value 'this is not { valid psd1 syntax'

    $result = Get-RuntimeVersionsConfig -Path $path -ErrorAction SilentlyContinue

    $result | Should -BeNullOrEmpty
  }
}
