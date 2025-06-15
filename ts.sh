#!/bin/sh


# functions

serv_stop() {
    status_output=$(service "$1" status 2>&1)
    printf "${green}${1}: ${reset}"

    case "$status_output" in
        "Service \"$1\" not found:")
            echo "not installed"
            return 1
            ;;
        *running*)
            if service "$1" stop >/dev/null 2>&1; then
                echo "stopped"
            else
                echo "Failed to stop"
                return 1
            fi
            ;;
        *inactive*)
            echo "already stopped"
            ;;
        *)
            echo "Unknown status: '$status_output'"
            return 1
            ;;
    esac
}



green='\033[32m'
yellow='\033[33m'
red='\033[0;31m'
reset='\033[0m'

test_site="google.com"
test_ip="8.8.8.8"
ip_geocheck="curl -u aa04d67c737a74: ipinfo.io --max-time 10 -s -x "     # "ipinfo.io"
vpn_iface="awg10"
opera_proxy="http://127.0.0.1:18080"
vless="http://127.0.0.1:1602"
clear


# проверяем наличие интерфейса awg10, при его отсутствии прекращаем выполнение скрипта
if ! ip a show dev awg10 >/dev/null 2>&1; then

    # Ищем интерфейсы, где ПРОТОКОЛ (proto) содержит 'amnezia' или 'vpn'
    interfaces=$(ubus call network.interface dump | jsonfilter -e '@.interface[*]' | while read -r iface; do
        proto=$(echo "$iface" | jsonfilter -e '@.proto')
        echo "$proto" | grep -qi -E 'amnezia|vpn' && \
        echo "$iface" | jsonfilter -e '@.interface'
    done)
    
    # Проверяем и выводим список
    if [ -z "$interfaces" ]; then
        echo "Интерфейсы с VPN-протоколами не найдены"
        exit 1
    fi
    
    echo "Выберите номер нужного вам VPN-интерфейса, затем нажмите Enter:"
    echo ================================================================
    count=1
    echo "$interfaces" | while read -r ifname; do
        echo "$count. $ifname"
        count=$((count+1))
    done
    
    # Выбор и запись в переменную
    read -p "Номер интерфейса: " num
    vpn_iface=$(echo "$interfaces" | sed -n "${num}p")
    
    [ -n "$vpn_iface" ] && echo "Выбрано: $vpn_iface" || { echo "Ошибка"; exit 1; }

fi
clear



echo INSTALLED
echo ==========
opkg list-installed | grep -i -E "podkop|unblock|zapret|ruantiblock|clash|passwall"
echo


echo STOPPING UNNECESSARY SERVICES
echo ==============================
serv_stop youtubeUnblock
serv_stop zapret
serv_stop ruantiblock

printf "${green}DoH: ${reset}" && [ -n "$(opkg find podkop | grep '0.2.5')" ] && { service https-dns-proxy start; service https-dns-proxy enable; } || { service https-dns-proxy stop; service https-dns-proxy disable; }
printf "${green}podkop [restart]: ${reset}" && service podkop restart >/dev/null 2>&1 && sleep 5 && service podkop status
echo

echo NETWORK_TEST
echo =============
printf "${green}PING DIRECT [ $test_site ]: ${reset}" && ping -q -c 2 $test_site | grep loss
printf "${green}PING DIRECT [ 8.8.8.8 ]:    ${reset}" && ping -q -c 2 $test_ip | grep loss
printf "${green}PING ${vpn_iface}  [ $test_site ]: ${reset}" && ping -I $vpn_iface -q -c 2 $test_site | grep loss
printf "${green}PING ${vpn_iface}  [ 8.8.8.8 ]:    ${reset}" && ping -I $vpn_iface -q -c 2 $test_ip | grep loss
echo

printf "${green}DIRECT [ $test_site ]: ${reset}     " && curl -s --max-time 10 $test_site | head -c 12
echo
printf "${green}AWG10  [ $test_site ]: ${reset}     " && curl -s --max-time 10 --interface ${vpn_iface} $test_site | head -c 12
echo
printf "${green}VLESS  [ $test_site ]:      ${reset}" && curl -s --max-time 10 127.0.0.1:1602 $test_site | head -c 12
echo
printf "${green}OPERA-PROXY [ $test_site ]: ${reset}" && curl -s --max-time 10 -x http://127.0.0.1:18080 $test_site | head -c 12
echo
printf "${green}OPERA-PROXY-COUNTRY [ $ip_check_site ]: ${reset}" && $ip_geocheck $opera_proxy | grep -i -E "country|message"
printf "${green}VLESS-COUNTRY [ $ip_check_site ]: ${reset}" && $ip_geocheck $vless | grep -i -E "country|message"
printf "${green}AWG-COUNTRY [ $ip_check_site ]: ${reset}" && $ip_geocheck -I $vpn_iface  | grep -i -E "country|message"

#printf "${green}AWG-IFACE-COUNTRY [ $ip_check_site ]:   ${reset}" && curl --interface ${vpn_iface} -s ipinfo.io | grep  -i -E "country|message"
echo DONE
echo
