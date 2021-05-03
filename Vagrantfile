# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "berdav/openbsd6.9"
  config.ssh.shell = "/bin/ksh"
  config.ssh.sudo_command = "/usr/bin/doas %c"

  config.vm.box_check_update = true

  config.vm.synced_folder ".", "/vagrant",disabled: true

  config.vm.provider "virtualbox" do |vb|
    # Customize the amount of memory on the VM:
    vb.memory = "2048"
    vb.cpus = "2"
  end

  config.vm.provision "shell", inline: <<-SHELL
    pkg_add python--%3.7
  SHELL
  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "playbook.yml"
  end
end
