require "yaml"

# Load up our vagrant config files -- vagrantconfig.yaml first
_config = YAML.load(File.open(File.join(File.dirname(__FILE__),
                    "vagrantconfig.yaml"), File::RDONLY).read)

CONF = _config
MOUNT_POINT = '/home/vagrant/migrate'


Vagrant::Config.run do |config|
    config.vm.box = "precise64"
    config.vm.box_url = "http://cloud-images.ubuntu.com/vagrant/saucy/current/precise-server-cloudimg-amd64-vagrant-disk1.box"

    Vagrant.configure("1") do |config|
        config.vm.customize ["modifyvm", :id, "--memory", CONF['memory']]
    end

    Vagrant.configure("2") do |config|
        config.vm.provider "virtualbox" do |v|
          v.name = "CHILI_REDMINE_VM"
          v.customize ["modifyvm", :id, "--memory", CONF['memory']]
        end
    end

    config.vm.forward_port 3000, 3000

    if CONF['boot_mode'] == 'gui'
        config.vm.boot_mode = :gui
    end

    config.vm.share_folder("vagrant-root", MOUNT_POINT, ".")
    config.vm.provision "shell", path: "vagrant_provision.sh"

end
