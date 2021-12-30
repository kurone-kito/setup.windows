Set-StrictMode -Version Latest

Write-Output Hello, world!
Invoke-WebRequest https://az792536.vo.msecnd.net/vms/VMBuild_20150916/Vagrant/IE11/IE11.Win81.Vagrant.zip -OutFile IE11.Win81.Vagrant.zip
Expand-Archive -Path IE11.Win81.Vagrant.zip -DestinationPath . -Force
