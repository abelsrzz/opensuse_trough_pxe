Vagrant.configure("2") do |config|
    
    #Definimos la máquina virtual del servidor
      config.vm.define "serverPXE" do |subconfig|
        #Indicamos el sistema operativo
        subconfig.vm.box = "debian/bullseye64"
        subconfig.vm.hostname = "serverPXE"
        #Indicamos la ip que tendrá dentro de nuestra lan
        subconfig.vm.network :private_network, ip: "192.168.1.10",
        virtualbox__intnet: "PXElan"
        
        subconfig.vm.provider :virtualbox do |vb|
          vb.name = "serverPXE"
          vb.gui = false
          vb.memory = "4096"
          vb.cpus = "4"
        end
      end
      
      #Creamos la máquina cliente
      config.vm.define "client", autostart: false do |cli|
        cli.vm.box = "TimGesekus/pxe-boot"
        cli.vm.hostname = "client"
        cli.ssh.connect_timeout = 1
        #Indicamos que obtendrá dirección IP por dhcp
        cli.vm.network "private_network", type: "dhcp",
        :adapter => 1, virtualbox__intnet: "PXElan"
    
        cli.vm.provider :virtualbox do |vb|
          vb.name = "client"
          vb.gui = true
        end 
      end
        
      #Creamos la máquina del router
      config.vm.define "router" do |subconfig|
        subconfig.vm.box = "debian/bullseye64"
        subconfig.vm.hostname = "router"
        subconfig.vm.network :private_network, ip: "192.168.1.1",
        virtualbox__intnet: "PXElan"
          
          #Ejecutamos en ella los comandos necesarios para convetirlo en un router
        subconfig.vm.provision "shell", inline: <<-SHELL
          apt update && apt install -y iptables
    
          echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
          sysctl -p
    
          iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
          iptables-save > /etc/iptables.up.rules
        SHELL
        
        subconfig.vm.provider :virtualbox do |vb|
          vb.name = "RouterFirewall"
          vb.gui = false
          vb.memory = 512
          vb.cpus = 1
        end
      end
    end