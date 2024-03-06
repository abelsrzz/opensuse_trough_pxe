#!/bin/bash

cd ~

apt update && apt install -y apache2 nfs-kernel-server dnsmasq unzip

mkdir syslinux && cd syslinux

wget https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.zip

unzip syslinux*

cd /tmp
apt-get download shim.signed grub-efi-amd64-signed
dpkg -x grub* ~/grub
dpkg -x shim-signed_1* ~/shim

mkdir -p /tftp/{bios,boot,grub}

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

cd ~

mkdir -p /var/www/html/opensuse

if [ -f "/vagrant/opensuse.iso" ]; then
    mount /vagrant/opensuse.iso /mnt
else
    wget https://download.opensuse.org/distribution/leap/15.5/iso/openSUSE-Leap-15.5-DVD-x86_64-Media.iso -O opensuse.iso
    mount opensuse.iso /mnt
fi

cp -rfv /mnt/* /var/www/html/opensuse
cp -rfv /mnt/.disk /var/www/html/opensuse

umount /mnt

mkdir -p /tftp/boot/opensuse/loader

cp -rfv /var/www/html/opensuse/boot/x86_64/loader/linux /tftp/boot/opensuse/loader

cp -rfv /var/www/html/opensuse/boot/x86_64/loader/initrd /tftp/boot/opensuse/loader

systemctl restart dnsmasq
systemctl restart nfs-kernel-server
