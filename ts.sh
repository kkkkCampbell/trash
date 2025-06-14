#!/bin/sh

PS1_BAK="$PS1"
PS1=""
clear
opkg list-installed | grep -i -E "podkop|unblock|zapret|ruantiblock"
service youtubeUnblock stop
service zapret stop
service ruantiblock stop
[ -n "$(opkg find podkop | grep '0.2.5')" ] && { service https-dns-proxy start; service https-dns-proxy enable; } || { service https-dns-proxy stop; service https-dns-proxy disable; }
service podkop restart && sleep 10
ping -q -c 1 ya.ru
ping -q -c 1 8.8.8.8
ping -I awg10 -q -c 1 ya.ru
ping -I awg10 -q -c 1 8.8.8.8
wget -T 5 -qO- https://ya.ru | head -c 50 && PS1="$PS1_BAK"
#
