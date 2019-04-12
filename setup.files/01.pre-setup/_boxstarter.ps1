Set-StrictMode -Version Latest

if (Test-Path -Path C:\ProgramData\Boxstarter) {
    cinst -y boxstarter
    choco upgrade -y boxstarter
}
else {
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://boxstarter.org/bootstrapper.ps1'))
    Get-Boxstarter -Force
}
