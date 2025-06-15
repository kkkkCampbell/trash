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
ip_check_site="ipinfo.io"

clear

# Получаем интерфейсы, содержащие vpn или amnezia (без учета регистра)
interfaces=($(ip -o link show | awk -F': ' '{print $2}' | grep -i -E 'vpn|amnezia' | grep -v lo))

if [ ${#interfaces[@]} -eq 0 ]; then
    echo "Не найдено интерфейсов с именами, содержащими 'vpn' или 'amnezia'"
    exit 1
fi

echo "Доступные VPN-интерфейсы:"
for i in "${!interfaces[@]}"; do
    echo "$((i+1)). ${interfaces[i]}"
done

# Запрашиваем выбор и записываем в переменную
read -p "Введите номер интерфейса: " num
if [[ $num -ge 1 && $num -le ${#interfaces[@]} ]]; then
    vpn_interface="${interfaces[$((num-1))]}"
    echo "Выбран интерфейс: $vpn_interface"
    
    # Здесь можно использовать переменную, например:
    # ip link set $vpn_interface up
else
    echo "Неверный номер интерфейса!"
    exit 1
fi




echo INSTALLED
echo ==========
opkg list-installed | grep -i -E "podkop|unblock|zapret|ruantiblock|clash|passwall"
echo

# проверяем наличие интерфейса awg10, при его отсутствии прекращаем выполнение скрипта
ip a show dev awg10 >/dev/null 2>&1 || { echo -e "${yellow}Error: Интерфейс awg10 не обнаружен.${reset} Роутер настроен не скриптом №4." >&2; exit 1; }

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
printf "${green}PING AWG10  [ $test_site ]: ${reset}" && ping -I awg10 -q -c 2 $test_site | grep loss
printf "${green}PING AWG10  [ 8.8.8.8 ]:    ${reset}" && ping -I awg10 -q -c 2 $test_ip | grep loss
echo

printf "${green}DIRECT [ $test_site ]: ${reset}     " && curl -s $test_site | head -c 12
echo

printf "${green}AWG10  [ $test_site ]: ${reset}     " && curl --interface awg10 -s $test_site | head -c 12
echo

printf "${green}OPERA-PROXY [ $test_site ]: ${reset}" && curl -s -x http://127.0.0.1:18080 $test_site | head -c 12
echo

printf "${green}OPERA-PROXY-COUNTRY [ $ip_check_site ]: ${reset}" && curl -s -x http://127.0.0.1:18080 $ip_check_site | grep -i -E "country|message"
#printf "${green}AWG-IFACE-COUNTRY [ $ip_check_site ]:   ${reset}" && curl --interface awg10 -s ipinfo.io | grep  -i -E "country|message"
echo DONE
echo
