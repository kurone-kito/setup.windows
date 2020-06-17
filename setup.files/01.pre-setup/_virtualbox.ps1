Set-StrictMode -Version Latest

$vagrant = Test-Path -Path C:\vagrant
$guest = Test-Path -Path D:\VBoxWindowsAdditions.exe

if ($vagrant -and $guest) {
  Get-ChildItem D:\cert -Filter *.cer | ForEach-Object { certutil -addstore -f 'TrustedPublisher' $_.FullName }
  Start-Process -FilePath D:\VBoxWindowsAdditions.exe -ArgumentList '/S' -Wait
}
else {
  Write-Output '[SKIP] Virtualbox GA: Detected the without Virtualbox environment.'
}
