#!/bin/sh

green='\033[32m'
reset='\033[0m'
test_site="https://ya.ru "

PS1_BAK="$PS1" && PS1="" && clear
echo INSTALLED
echo ==========
opkg list-installed | grep -i -E "podkop|unblock|zapret|ruantiblock"
echo

echo STOPPING UNNECESSARY SERVICES
echo =============================
printf "${green}youtubeUnblock: ${reset}" && service youtubeUnblock stop
printf "${green}zapret: ${reset}" && service zapret stop
printf "${green}ruantiblock: ${reset}" && service ruantiblock stop
printf "${green}DoH: ${reset}" && [ -n "$(opkg find podkop | grep '0.2.5')" ] && { service https-dns-proxy start; service https-dns-proxy enable; } || { service https-dns-proxy stop; service https-dns-proxy disable; }
printf "${green}podkop [restart]: ${reset}" && service podkop restart && sleep 10
echo

echo NETWORK_TEST
echo =============
ping -q -c 1 ya.ru
ping -q -c 1 8.8.8.8
ping -I awg10 -q -c 1 ya.ru
ping -I awg10 -q -c 1 8.8.8.8
printf "${green}DIRECT [$test_site]: ${reset}" && wget -T 5 -qO- $test_site | head -c 50 && echo
printf "${green}OPERA-PROXY [$test_site]: ${reset}" && http_proxy="http://127.0.0.1:18080" wget -T 5 -qO- $test_site | head -c 50 && echo
PS1="$PS1_BAK"
echo DONE
echo
