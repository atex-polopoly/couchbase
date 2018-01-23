Vagrant.configure("2") do |config|
    config.vm.network "private_network", ip: "192.0.0.1"
end