# EN DESARROLLO
# Instalación PXE

Este proyecto consiste enla instalación de un servidor PXE para instalar un sistema operativo <a href="https://get.opensuse.org/leap/15.5/#download">Open SUSE Leap 15.5</a>.

En mi caso he decidido hacerlo con Vagrant para facilitar el proceso de crear las máquinas virtuales con las características necesarias.

Máquinas que utilizaremos:

- Servidor PXE (Debian 11)
- Router-Firewall (Debian 11)
- Cliente (Máquina vacía)

La máquina de Servidor PXE será la que sirva los archivos necesarios para realizar la instalación a través de la red y el Router-Firewall redirigirá el tráfico de internet a la máquina cliente y viceversa para que así esta tenga conexión para realizar todas las descargas necesarias.

Vagrantfile que utilizaré es el siguiente:

```ruby
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
```

## Pasos a seguir

 #### Levantamos las máquinas

```bash
vagrant up serverPXE router
```

![image-20240305173656194](.markdown_images/`README`/image-20240305173656194-17096566488531.png)

#### Nos conectamos a la máquina de servidor

 ```bash
 vagrant ssh serverPXE
 ```

#### Ejecutamos los siguientes comandos:

```bash
sudo su -
```

**Descargar paquetes**

```bash
apt update && apt install -y nfs-kernel-server dnsmasq unzip
```

![image-20240305174144811](.markdown_images/`README`/image-20240305174144811.png)

**Crear carpeta para archivos de sistema**

```bash
mkdir syslinux && cd syslinux
```

**Descargamos los fichero de kernel**

```bash
wget https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.zip

unzip syslinux*
```

![image-20240305174235660](.markdown_images/`README`/image-20240305174235660.png)

**Descargamos archivos de grub y de shim**

```bash
cd /tmp
apt-get download shim.signed grub-efi-amd64-signed
dpkg -x grub* ~/grub
dpkg -x shim-signed_1* ~/shim
```

![image-20240305174324661](.markdown_images/`README`/image-20240305174324661.png)

**Creamos el directorio donde se alojarán los archivos del servidor tftp**

```bash
mkdir -p /tftp/{bios,boot,grub}
```

**Copiamos los ficheros de configuración**

###### Para poder copiar los archivos de la carpeta /vagrant debemos tenerlos en el mismo directorio que nuestro Vagrantfile

```bash
cp -v /vagrant/files/exports /etc/exports
systemctl restart nfs-kernel-server

cp -v /vagrant/files/dnsmasq.conf /etc/dnsmasq.conf

cd ~/syslinux

cp -v bios/{com32/{elflink/ldlinux/ldlinux.c32,libutil/libutil.c32,menu/{menu.c32,vesamenu.c32}},core/{pxelinux.0,lpxelinux.0}} /tftp/bios

cd ~

cp -v grub/usr/lib/grub/x86_64-efi-signed/grubnetx64.efi.signed  /tftp/grubx64.efi
cp -v shim/usr/lib/shim/shimx64.efi.signed  /tftp/grub/bootx64.efi

cp -v /boot/grub/{grub.cfg,unicode.pf2} /tftp/grub/


sudo ln -s /tftp/boot  /tftp/bios/boot


mkdir /tftp/bios/pxelinux.cfg
cp -v /vagrant/files/default /tftp/bios/pxelinux.cfg/default

cp /vagrant/files/dnsmasq.conf /etc/dnsmasq.conf
systemctl restart dnsmasq
```

#### **Preparamos la imagen iso para la instalación**

**Descargamos la imagen iso**

```bash
cd ~

wget https://download.opensuse.org/distribution/leap/15.5/iso/openSUSE-Leap-15.5-DVD-x86_64-Media.iso -O opensuse.iso
```

![image-20240305174907428](.markdown_images/`README`/image-20240305174907428.png)

**Creamos las carpetas para alojar la iso**

```bash
mkdir -p /var/www/html/opensuse

mount opensuse.iso /mnt

cp -rfv /mnt/* /var/www/html/opensuse
cp -rfv /mnt/.disk /var/www/html/opensuse

umount /mnt

mkdir -p /tftp/boot/opensuse/loader

cp -rfv /var/www/html/opensuse/boot/x86_64/loader/linux /tftp/boot/opensuse/loader

cp -rfv /var/www/html/opensuse/boot/x86_64/loader/initrd /tftp/boot/opensuse/loader
```

**Creamos el fichero default**

`nano /tftp/bios/pxelinux.cfg/default`

```cfg
DEFAULT menu.c32
MENU TITLE PANEL PXE - ABELSRZ
PROMPT 0 
TIMEOUT 0

MENU COLOR TABMSG   37;40   #ffffffff #00000000
MENU COLOR TITLE    1;36;40 #ffffffff #00000000 
MENU COLOR SEL      30;46   #ffffffff #00000000
MENU COLOR UNSEL    40;37   #ffffffff #00000000
MENU COLOR BORDER   37;40   #ffffffff #00000000


LABEL OpenSUSE
        kernel /boot/opensuse/loader/linux
        append initrd=/boot/opensuse/loader/initrd splash=silent ip=dhcp install=nfs://192.168.1.10:/var/www/html/opensuse boot=loader ramdisk_size=512000 ramdisk_blocksize=4096 language=es_ES keytable=es quiet quiet showopts
```

**Reiniciamos los servicios**

```bash
systemctl restart dnsmasq
systemctl restart nfs-kernel-server
```

#### Probamos si funciona

```
vagrant up client
```

