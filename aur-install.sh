#!/bin/bash -e

local package=$1
local user='prova'

wget https://aur.archlinux.org/cgit/aur.git/snapshot/${package}.tar.gz -o /dev/null
tar -xf ${package}.tar.gz
cd ${package}
makepkg -fs --noconfirm
echo ${user} | sudo -S pacman --noconfirm -U ${package}*.pkg.tar.xz
cd ..
rm -f ${package}.tar.gz
rm -rf ${package}
