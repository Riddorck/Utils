#!/bin/bash -e

. CONFIG


GET_ETH(){
	ip link | grep "^[0-9]: e" | cut -d":" -f2 | sed 's_[[:space:]]__g'
}

GET_WIFI(){
	ip link | grep "^[0-9]: w" | cut -d":" -f2 | sed 's_[[:space:]]__g'
}

ETH_CONNECTION(){
	local eth=$(GET_ETH)
	echo "Description=Network Connection
Interface=${eth}
Connection=ethernet
IP=dhcp" > /etc/netctl/eth-connection
}

WIFI_CONNECTION(){
	local wifi=$(GET_WIFI)
	local DESCRIPTION=$(echo "${1}" | cut -d":" -f1)
	local ESSID=$(echo "${1}" | cut -d":" -f2)
	local PASSWORD=$(echo "${1}" | cut -d":" -f3)
	echo "Description='${DESCRIPTION}'
Interface=${wifi}
Connection=wireless
Security=wpa
ESSID=${ESSID}
IP=dhcp
Key=${PASSWORD}" > /etc/netctl/${wifi}-${ESSID}
}

WIFI_CONNECTIONS(){
	let local n=$(echo "${1}" | grep -o ";" | wc -l)+1
	for i in $(seq 1 ${n}); do
		local wifi_config=$(echo "${1}" | cut -d";" -f${i})
		WIFI_CONNECTION "${wifi_config}"
	done
}

BIOS(){
	local disk=${1}
	parted /dev/${disk} mklabel msdos
	parted /dev/${disk} mktable msdos
	parted /dev/${disk} mkpart primary ext4 1M 100%
	parted /dev/${disk} set 1 boot on
	mkfs.ext4 /dev/${disk}1

	mount /dev/${disk}1 /mnt
}


UEFI(){
	local disk=${1}
	parted /dev/${disk} mklabel gpt
	parted /dev/${disk} mktable gpt
	parted /dev/${disk} mkpart primary fat32 1M 512M
	parted /dev/${disk} mkpart primary ext4 512M 100%
	parted /dev/${disk} set 1 boot on
	mkfs.fat -s1 -F32 /dev/${disk}1
	mkfs.ext4 /dev/${disk}2

	mount /dev/${disk}2 /mnt
	mkdir /mnt/boot
	mount /dev/${disk}1 /mnt/boot
}

INSTALL_GRUB(){
	local disk=${1}
	local bios=${2}
	if [ "${bios}" == "BIOS" ]; then
		pacman -S --noconfirm grub
		grub-install /dev/${disk}
	elif [ "${bios}" == "UEFI" ]; then
		pacman -S --noconfirm grub efibootmgr
		grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
	fi
	sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/' /etc/default/grub
	grub-mkconfig -o /boot/grub/grub.cfg
}

CREATE_USER(){
	local user=${1}
	useradd -m -p $(perl -e 'print crypt($ARGV[0], "password")' ${user}) ${user}
	echo "${user} ALL=(ALL:ALL) ALL" | (sudo EDITOR="tee -a" visudo)
}

AUR_INSTALL(){
	local package=${1}
	local user=${2}
	wget https://aur.archlinux.org/cgit/aur.git/snapshot/${package}.tar.gz -o /dev/null
	tar -xf ${package}.tar.gz
	cd ${package}
	makepkg -fs --noconfirm
	echo ${user} | sudo -S pacman --noconfirm -U ${package}*.pkg.tar.xz
	cd ..
	rm -f ${package}.tar.gz
	rm -rf ${package}
}

INSTALL_YAOURT(){
	AUR_INSTALL package-query ${1}
	AUR_INSTALL yaourt ${1}
}

CREATE_HOME_SCRIPTS(){
	local user=${1}

	echo '[[ -f ~/.bashrc ]] && . ~/.bashrc
if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
    exec startx
fi' > .bash_profile

	echo "setxkbmap it &
exec i3" > .xinitrc
chmod +x .xinitrc
}

NOCHROOT(){
	WIFI_CONNECTIONS "${WIFI_CONFIG}"
	ETH_CONNECTION

	if [ "${CONNECTION}" == "wifi" ]; then
		netctl start $(GET_WIFI)-${ESSID}
	elif [ "{$CONNECTION}" == "eth" ]; then
		netctl start eth-connection
	fi

	if [ "${BIOS}" == "BIOS" ]; then
		BIOS ${DISK}
	elif [ "${BIOS}" == "UEFI" ]; then
		UEFI ${DISK}
	fi

	pacman-key --init
	pacman-key --populate archlinux
	pacman-key --refresh-keys

	pacstrap /mnt base base-devel
	genfstab -p /mnt >> /mnt/etc/fstab
	
	cp -r /etc/netctl/* /mnt/etc/netctl/
	cp ${0} /mnt/${0}
	cp CONFIG /mnt/CONFIG
	arch-chroot /mnt /${0} chroot
}

CHROOT(){
	echo ${HOSTNAME} > /etc/hostname

	ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
	sed -i 's/#en_US/en_US/' /etc/locale.gen
	sed -i 's/#it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/' /etc/locale.gen
	locale-gen
	echo "LANG=it_IT.UTF-8" > /etc/locale.conf
	echo "KEYMAP=it" > /etc/vconsole.conf

	pacman -S --noconfirm sudo wget
	echo "Defaults visiblepw" | (EDITOR="tee -a" visudo)
	CREATE_USER ${USERNAME}
	
	INSTALL_GRUB ${DISK} ${BIOS}
	
	pacman -S --noconfirm linux-headers acpi
	pacman -S --noconfirm dhcpcd dhclient wpa_supplicant wpa_actiond iproute

	pacman -S --noconfirm ntp
	ntpd -gq
	hwclock --systohc

	pacman -S --noconfirm xorg xorg-xinit xorg-xsetroot
	pacman -S --noconfirm i3 alsa-utils net-tools acpi linux-headers
	pacman -S --noconfirm dhcpcd dhclient wpa_supplicant wpa_actiond iproute
	pacman -S --noconfirm wget terminator git dmenu ttf-freefont
	pacman -S --noconfirm thunar viewnior chromium notepadqq eclipse
	pacman -S --noconfirm thunar-archive-plugin unrar p7zip
	pacman -S --noconfirm libreoffice vlc qt4 virtualbox keepass virtualbox-guest-utils
	
	if [ "${CONNECTION}" == "wifi" ]; then
		netctl enable $(GET_WIFI)-${ESSID}
	elif [ "${CONNECTION}" == "eth" ]; then
		netctl enable eth-connection
	fi

	if [ "${VGA}" == "nvidia" ]; then
		pacman -S --noconfirm nvidia
	elif [ "${VGA}" == "amd" ]; then
		pacman -S --noconfirm xf86-video-amdgpu
	fi

	su ${USERNAME} -c "/${0} user"
	mkinitcpio -p linux
	passwd
	exit
}

USER(){
	local user=$(whoami)
	pushd /home/${user}/
	
	CREATE_HOME_SCRIPTS ${user}

	INSTALL_YAOURT ${user}
	
	yaourt -S spotify

	popd
}

if [ ${#} -ge 1 ]; then
	if [ ${1} = "chroot" ]; then
		CHROOT
	elif [ ${1} = "user" ]; then
		USER
	elif [ ${1} = "yaourt" ]; then
		INSTALL_YAOURT
	else
		NOCHROOT
	fi
else
	NOCHROOT
fi
