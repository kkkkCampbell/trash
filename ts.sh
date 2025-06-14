#!/bin/sh

green='\033[32m'
reset='\033[0m'
test_site="google.com"
ip_check_site="ipinfo.io"

PS1_BAK="$PS1" && PS1="" && clear
echo INSTALLED
echo =========
opkg list-installed | grep -i -E "podkop|unblock|zapret|ruantiblock"
echo
echo STOPPING UNNECESSARY SERVICES
echo =============================
printf "${green}youtubeUnblock: ${reset}" && service youtubeUnblock stop
printf "${green}zapret: ${reset}" && service zapret stop
printf "${green}ruantiblock: ${reset}" && service ruantiblock stop
printf "${green}DoH: ${reset}" && [ -n "$(opkg find podkop | grep '0.2.5')" ] && { service https-dns-proxy start; service https-dns-proxy enable; } || { service https-dns-proxy stop; service https-dns-proxy disable; }
printf "${green}podkop [restart]: ${reset}" && service podkop restart >/dev/null 2>&1 && sleep 10 && service podkop status && echo
echo
echo NETWORK_TEST
echo ============
printf "${green}PING DIRECT: ${reset}" && ping -q -c 1 $test_site 
printf "${green}PING DIRECT: ${reset}" && ping -q -c 1 8.8.8.8
printf "${green}PING AWG10: ${reset}" && ping -I awg10 -q -c 1 $test_site
printf "${green}PING AWG10: ${reset}" && ping -I awg10 -q -c 1 8.8.8.8 
echo
printf "${green}DIRECT [ $test_site ]: ${reset}" && curl -s $test_site | head -c 50
echo
printf "${green}AWG10 [ $test_site ]: ${reset}" && curl --interface awg10 -s $test_site | head -c 50
echo
printf "${green}OPERA-PROXY [ $test_site ]: ${reset}" && curl -s -x http://127.0.0.1:18080 $test_site | head -c 50
echo
printf "${green}OPERA-PROXY-COUNTRY [ $ip_check_site ]: ${reset}" && curl -s -x http://127.0.0.1:18080 https://ipinfo.io/ | grep country
PS1="$PS1_BAK"
echo DONE
echo
