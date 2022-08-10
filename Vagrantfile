# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'etc'

# specifies the audio driver
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

# specifies the total memory size
total_memory = case RUBY_PLATFORM
  when /linux/
    `cat /proc/meminfo | grep MemTotal | grep -o '[0-9]\\+'`.to_i
  when /darwin|freebsd/
    `sysctl -a | grep -e hw.physmem -e hw.memsize | grep -o '[0-9]\\+'`.to_i
  when /cygwin|mswin|mingw|bccwin|wince|emx/
    `wmic ComputerSystem get TotalPhysicalMemory | findstr /r /c:"[0-9][0-9]*"`.to_i
  else
    raise 'Unknown RUBY_PLATFORM=#{RUBY_PLATFORM}'
  end
total_memory /= 1048576

Vagrant.configure('2') do |config|
  config.vagrant.plugins = [
    'vagrant-reload',
    'vagrant-vbguest',
    'vagrant-disksize',
  ]
  config.vm.define 'win8.1' do |atomic|
    atomic.vm.box = 'jaswsinc/windows81'
    atomic.vm.provider 'virtualbox' do |vb|
      vb.name = 'setup-windows-8.1'
      vb.memory = ([total_memory / 16, 1536].max).to_s
    end
    atomic.winrm.username = 'IEUser'
    atomic.winrm.password = 'Passw0rd!'
  end
  config.vm.define 'win10' do |atomic|
    atomic.vm.box = 'gusztavvargadr/windows-10'
    atomic.vm.provider 'virtualbox' do |vb|
      vb.name = 'setup-windows-10'
      vb.memory = ([total_memory / 10, 2048].max).to_s
     end
  end
  config.vm.define 'win11', primary: true do |atomic|
    atomic.vm.box = 'gusztavvargadr/windows-11'
    atomic.vm.provider 'virtualbox' do |vb|
      vb.name = 'setup-windows-11'
      vb.memory = ([total_memory / 10, 2048].max).to_s
    end
  end
  config.vm.define 'ws2019' do |atomic|
    atomic.vm.box = 'gusztavvargadr/windows-server'
    atomic.vm.box_version = '1809.0.2207'
    atomic.vm.provider 'virtualbox' do |vb|
      vb.name = 'setup-windows-2019'
      vb.memory = ([total_memory / 10, 2048].max).to_s
    end
  end
  config.vm.define 'ws2022' do |atomic|
    atomic.vm.box = 'gusztavvargadr/windows-server'
    atomic.vm.box_version = '2102.0.2207'
    atomic.vm.provider 'virtualbox' do |vb|
      vb.name = 'setup-windows-2022'
      vb.memory = ([total_memory / 10, 2048].max).to_s
    end
  end
  config.disksize.size = '168GB'
  config.vm.box_check_update = true
  config.vm.guest = :windows
  config.vm.communicator = 'winrm'
  config.vm.network :forwarded_port, guest: 5985, host: 5985, id: 'winrm', auto_correct: true
  config.vm.network :forwarded_port, guest: 3389, host: 3389, id: 'rdp', auto_correct: true
  config.winrm.retry_limit = 30
  config.winrm.retry_delay = 10
  config.vm.provider 'virtualbox' do |vb|
    vb.gui = true
    vb.cpus = [Etc.nprocessors, [Etc.nprocessors / 4, 2].max].min
    vb.linked_clone = true
    vb.customize [
      'modifyvm', :id,
      '--accelerate3d', 'on',
      '--acpi', 'on',
      '--apic', 'on',
      '--audio', audio_driver,
      '--audioin', 'on',
      '--audioout', 'on',
      '--audiocontroller', 'hda',
      '--biosapic', 'apic',
      '--bioslogofadeout', 'on',
      '--chipset', 'ich9',
      '--clipboard', 'bidirectional',
      '--graphicscontroller', 'vboxsvga',
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
      '--vram', '192',
      '--vtxvpid', 'on',
      '--vtxux', 'on',
    ]
  end
  config.vm.provision 'invoke the deploy script', type: 'shell', path: 't/deploy.ps1'
  config.vm.provision :reload
end
