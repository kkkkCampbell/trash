#!/bin/sh

# Network availability check. Especially for RR and script #4

green='\033[32m'
yellow='\033[33m'
red='\033[0;31m'
reset='\033[0m'

test_site="google.com"
test_ip="8.8.8.8"
vpn_iface="awg10"

geocheck_site="ipinfo.io"
geocheck_proxy="curl -u aa04d67c737a74: ${geocheck_site} -m 10 -s -x "
geocheck_vpn="curl -u aa04d67c737a74: ${geocheck_site} -m 10 -s --interface "
geocheck_vless="curl -m 10 -s -u aa04d67c737a74: ${geocheck_site}"

opera_proxy="http://127.0.0.1:18080"
vless_proxy="sing-box tools fetch ${geocheck_site}?token=aa04d67c737a74"
vless_proxy1="sing-box tools fetch "
user_agent="Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0"

novpn = 0

# functions

# Функция для обработки сервисов
serv_stop() {
    local SERVICES="$1"
    RESTART_SCRIPT="/tmp/restart_services.sh"
    local has_services=0
    
    # Обнуляем файл
    echo "#!/bin/sh" > "$RESTART_SCRIPT"
    chmod a+x "$RESTART_SCRIPT"
    
    for service in $SERVICES; do
        if [ -f "/etc/init.d/$service" ]; then
            has_services=1
            printf "${green}%s${reset} " "${service}:"
            
            if /etc/init.d/"$service" status 2>/dev/null | grep -q 'running'; then
                printf "останавливаем..."
                
                if /etc/init.d/"$service" stop >/dev/null 2>&1; then
                    echo " [успешно остановлен]"
                    echo "/etc/init.d/$service start >/dev/null 2>&1" >> "$RESTART_SCRIPT"
                else
                    echo " [ошибка остановки]"
                fi
            else
                echo "остановлен ранее"
            fi
        fi
    done

}

clear

if ! ip a show dev awg10 >/dev/null 2>&1; then
	# Ищем интерфейсы, где ПРОТОКОЛ (proto) содержит 'amnezia' или 'vpn'
	interfaces=$(ubus call network.interface dump | jsonfilter -e '@.interface[*]' | while read -r iface; do
		proto=$(echo "$iface" | jsonfilter -e '@.proto')
		echo "$proto" | grep -qi -E 'amnezia|vpn' && \
		echo "$iface" | jsonfilter -e '@.interface'
	done)

	# Проверяем и выводим список интерфейсов
	if [ -z "$interfaces" ]; then
		echo "Интерфейсы с VPN-протоколами не найдены"
		$novpn = 1 #exit 1
	fi

	echo "VPN-интерфейсы (по протоколу):"
	count=1
	echo "$interfaces" | while read -r ifname; do
		echo "$count. $ifname"
		count=$((count+1))
	done

	# Выбор и запись в переменную
	read -p "Номер интерфейса: " num
	vpn_iface=$(echo "$interfaces" | sed -n "${num}p")

	[ -n "${vpn_iface}" ] && echo "Выбрано: ${vpn_iface}" || { echo "Ошибка"; exit 1; }
fi

clear

echo "INSTALLED"
echo ==========
opkg list-installed | grep -i -E "podkop|unblock|zapret|ruantiblock|clash|passwall"
echo

echo "STOP|START SERVICES"
echo ====================
serv_stop "youtubeUnblock zapret ruantiblock clash passwall"


printf "${green}DoH: ${reset}" && [ -n "$(opkg find podkop | grep '0.2.5')" ] && \
{ service https-dns-proxy start; service https-dns-proxy enable; } || { service https-dns-proxy stop; service https-dns-proxy disable; }
printf "${green}podkop [restart]: ${reset}" && service podkop restart >/dev/null 2>&1 && sleep 5 && service podkop status
printf "${green}sing-box [status]: ${reset}" && service sing-box status
printf "${green}opera-proxy [status]: ${reset}" && service opera-proxy status
echo

echo "NETWORK_TEST"
echo =============
printf "${green}PING DIRECT [ ${test_site} ]: ${reset}"  && ping -q -c 4 $test_site | grep loss
printf "${green}PING DIRECT    [ ${test_ip} ]: ${reset}" && ping -q -c 4 $test_ip | grep loss
if [ "$novpn" -eq 0 ]; then
	printf "${green}PING VPN    [ ${test_site} ]: ${reset}"  && ping -q -c 4 -I $vpn_iface $test_site | grep loss
	printf "${green}PING VPN       [ ${test_ip} ]: ${reset}" && ping  -q -c 4 -I $vpn_iface $test_ip | grep loss
fi
printf "${green}DIRECT      [ ${test_site} ]: ${reset}"  && curl -m 10 -s $test_site | head -c 12 && echo
printf "${green}VPN         [ ${test_site} ]: ${reset}"  && curl -m 10 -s --interface $vpn_iface $test_site | head -c 12  && echo
printf "${green}OPERA-PROXY [ ${test_site} ]: ${reset}"  && curl -m 10 -s -x $opera_proxy $test_site | head -c 12 && echo
printf "${green}VLESS       [ ${test_site} ]: ${reset}"  && sing-box tools fetch $test_site -D /etc/sing-box | head -c 15 && echo
echo

echo "YOUTUBE"
echo ========
test=$(curl -4 -s --user-agent "${user_agent}" -x ${opera_proxy} https://www.google.com | sed -n 's/.*"[a-z]\{2\}_\([A-Z]\{2\}\)".*/\1/p')
printf "${green}OPERA-PROXY-COUNTRY: ${reset}" && echo $test
if [ "$novpn" -eq 0 ]; then
	test=$(curl -4 -s --user-agent "${user_agent}" --interface ${vpn_iface} https://www.google.com | sed -n 's/.*"[a-z]\{2\}_\([A-Z]\{2\}\)".*/\1/p')
	printf "${green}VPN-COUNTRY: ${reset}" && echo $test
fi
test=$(curl -4 -s --user-agent "${user_agent}" ${vless_proxy1} https://www.google.com | sed -n 's/.*"[a-z]\{2\}_\([A-Z]\{2\}\)".*/\1/p')
printf "${green}VLESS-PROXY-COUNTRY: ${reset}" && echo $test
echo

echo "IPINFO.IO"
echo ==========
vless_ip=$(sing-box tools fetch ifconfig.me -D /etc/sing-box 2>/dev/null)
printf "${green}OPERA-PROXY-COUNTRY: ${reset}%s\n" "$(${geocheck_proxy}${opera_proxy} | grep -i -E 'country|message')"
if [ "$novpn" -eq 0 ]; then
	printf "${green}VPN-COUNTRY:        ${reset} %s\n" "$(${geocheck_vpn}${vpn_iface} | grep -i -E "country|message")"
fi
printf "${green}VLESS-COUNTRY: ${reset}      %s\n" "$(${geocheck_vless}/${vless_ip} | grep -i -E 'country|message')"; echo

if [ "$novpn" -eq 0 ]; then
	printf "${green}VPN-INTERFACE-NAME: ${reset}   "
	echo "\"${vpn_iface}\""
fi
if [ $(wc -l < "$RESTART_SCRIPT") -gt 1 ]; then "$RESTART_SCRIPT"; fi
#rm -f "$RESTART_SCRIPT"

echo DONE
echo
