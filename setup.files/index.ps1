Set-StrictMode -Version Latest
Write-Output (Get-WmiObject win32_OperatingSystem).Caption

$cred = Get-Credential $env:username

if ($null -eq $cred) {
  Write-Warning 'Abort.'
}
else {
  Push-Location .\01.pre-setup
  .\index.ps1
  Pop-Location

  Push-Location .\02.boxstarter
  .\index.ps1 $cred
  Pop-Location
}
