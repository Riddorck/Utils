#!/bin/bash

w=$(xrandr | grep Screen | awk '{print $8}')
h=$(xrandr | grep Screen | awk '{print $10}') | cut -d"," -f1
img=img.png
sgrana=4
let s1=100/${sgrana}
let s2=100*${sgrana}
alpha=50
scrot /tmp/screen.png
convert /tmp/screen.png -scale ${s1}% -scale ${s2}% /tmp/screen.png
convert ${img} -resize ${w}x${h} -alpha set  -channel A -evaluate set ${alpha}% /tmp/screen2.png
convert /tmp/screen.png /tmp/screen2.png -gravity center -composite -matte /tmp/screen.png
i3lock -t -i /tmp/screen.png
