# Install chocolatey
if (gcm choco -ea SilentlyContinue) {
    Write-Information 'Chocolatey: Already installed. skip...'
}
else {
    Set-ExecutionPolicy Bypass -Scope Process -Force;
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}
