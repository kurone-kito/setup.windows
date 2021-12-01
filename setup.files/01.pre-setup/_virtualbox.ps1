Set-StrictMode -Version Latest

# Install the latest Virtualbox Windows Additions if detected in the Vagrant environment.
$vagrant = Test-Path -Path C:\vagrant
$guest = Test-Path -Path D:\VBoxWindowsAdditions.exe

if ($vagrant -and $guest) {
  Get-ChildItem D:\cert -Filter *.cer | ForEach-Object { certutil -addstore -f 'TrustedPublisher' $_.FullName }
  Start-Process -FilePath D:\VBoxWindowsAdditions.exe -ArgumentList '/S' -Wait
}
else {
  Write-Output '[SKIP] Virtualbox GA: Detected the non-Virtualbox environment.'
}
