# -*- mode: ruby -*-
# vi: set ft=ruby :

audio_driver = case RUBY_PLATFORM
  when /linux/
    'alsa'
  when /darwin/
    'coreaudio'
  when /cygwin|mswin|mingw|bccwin|wince|emx/
    'dsound'
  else
    raise 'Unknown RUBY_PLATFORM=#{RUBY_PLATFORM}'
  end
guest_iso = case RUBY_PLATFORM
  when /linux/
    '/usr/share/virtualbox/VBoxGuestAdditions.iso'
  when /darwin/
    '/Applications/VirtualBox.app/Contents/MacOS/VBoxGuestAdditions.iso'
  when /cygwin|mswin|mingw|bccwin|wince|emx/
    '%PROGRAMFILES%/Oracle/VirtualBox/VBoxGuestAdditions.iso'
  else
    raise 'Unknown RUBY_PLATFORM=#{RUBY_PLATFORM}'
  end


Vagrant.configure('2') do |config|
  config.vagrant.plugins = 'vagrant-reload'
  config.vm.define 'win8.1' do |atomic|
    atomic.vm.box = 'opentable/win-8.1-enterprise-amd64-nocm'
    atomic.vm.provider 'virtualbox' do |vb|
      vb.name = 'setup-windows-8.1'
      vb.memory = '3072'
    end
  end
  config.vm.define 'win10' do |atomic|
    atomic.vm.box = 'senglin/win-10-enterprise-vs2015community'
    atomic.vm.provider 'virtualbox' do |vb|
      vb.name = 'setup-windows-10'
      vb.memory = '4096'
    end
  end
  config.vm.box_check_update = true
  config.vm.guest = :windows
  config.vm.communicator = 'winrm'
  config.winrm.username = 'vagrant'
  config.winrm.password = 'vagrant'
  config.vm.provider 'virtualbox' do |vb|
    vb.gui = true
    vb.cpus = 4
    vb.linked_clone = true
    vb.customize [
      'modifyvm', :id,
      '--accelerate3d', 'on',
      '--acpi', 'on',
      '--apic', 'on',
      '--audio', audio_driver,
      '--audiocontroller', 'hda',
      '--biosapic', 'apic',
      '--bioslogofadeout', 'on',
      '--chipset', 'ich9',
      # '--graphicscontroller', 'vboxsvga',
      '--hpet', 'on',
      '--hwvirtex', 'on',
      '--ioapic', 'on',
      '--keyboard', 'usb',
      '--largepages', 'on',
      '--longmode', 'on',
      '--mouse', 'usb',
      '--nestedpaging', 'on',
      '--nested-hw-virt', 'on',
      '--pae', 'on',
      '--paravirtprovider', 'default',
      '--usb', 'on',
      '--usbxhci', 'on',
      '--vram', '128',
      '--vtxvpid', 'on',
      '--vtxux', 'on',
    ]
    vb.customize [
      'storageattach', :id,
      '--storagectl', 'IDE Controller',
      '--port', '0',
      '--device', '1',
      '--type', 'dvddrive',
      '--medium', guest_iso
    ]
  end
  config.vm.provision 'Install...Virtualbox guest additions', type: 'shell', path: 'setup.files/01.pre-setup/_virtualbox.ps1'
  config.vm.provision :reload
  # config.vm.provision 'setup', type: 'shell', path: 'setup.cmd'
end
