Param([string]$User = 'vagrant', [string]$Password = 'vagrant');
Set-StrictMode -Version Latest

New-ItemProperty -Force -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name AutoAdminLogon -PropertyType String -Value '1'
New-ItemProperty -Force -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name DefaultUserName -PropertyType String -Value $User
New-ItemProperty -Force -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name DefaultPassword -PropertyType String -Value $Password
