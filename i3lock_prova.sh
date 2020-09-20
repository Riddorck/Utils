#!/bin/bash

img=/tmp/i3lock-screen.png
img2=/tmp/i3lock-screen2.png

scrot ${img} -d 0.1
convert ${img} -blur 150x50 ${img2}

i3lock -t -i ${img2}

sleep 0.1
rm -f ${img}