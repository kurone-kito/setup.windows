Set-StrictMode -Version Latest

if (Test-Path -Path C:\ProgramData\Boxstarter) {
  cinst -y boxstarter
  choco upgrade -y boxstarter
}
else {
  . { Invoke-WebRequest -useb https://boxstarter.org/bootstrapper.ps1 } | Invoke-Expression
  Get-Boxstarter -Force
}
