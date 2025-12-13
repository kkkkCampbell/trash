#!/bin/ash
# /tmp/blockcheck_wrapper.sh

MAX_STRATEGIES=${MAX_STRATEGIES:-0}
SCANLEVEL=${SCANLEVEL:-"standart"}
REPEATS=${REPEATS:-1}
PARALLEL=${PARALLEL:-1}
SKIP_TPWS=${SKIP_TPWS:-1}
ENABLE_HTTP=${ENABLE_HTTP:-0}
ENABLE_HTTPS_TLS12=${ENABLE_HTTPS_TLS12:-1}
ENABLE_HTTPS_TLS13=${ENABLE_HTTPS_TLS13:-1}
FWTYPE=${FWTYPE:-"nftables"}
DOMAINS=${DOMAINS:-"rr5---sn-385ou-8v1s.googlevideo.com"}
IPVS=${IPVS:-4}
CURL_MAX_TIME=${CURL_MAX_TIME:-2}
BATCH=1

STRATEGIES_FOUND=0
OUTPUT_FILE="/tmp/resscan/final.txt"
PREVIOUS_LINE=""

: > "$OUTPUT_FILE"

service zapret stop > /dev/null 2>&1
opkg install netcat > /dev/null 2>&1

echo "=== Запуск blockcheck с лимитом стратегий: $MAX_STRATEGIES ==="
echo

# Основной pipeline
sh /opt/zapret/blockcheck.sh 2>&1 | tee /dev/tty | {
    while read -r line; do
        # Сохраняем предыдущую строку для обработки
        if [ -n "$PREVIOUS_LINE" ]; then
            case "$line" in
                *"!!!!! AVAILABLE !!!!!"*)
                    # Ищем часть строки начиная с "--" и до конца
                    extracted=$(echo "$PREVIOUS_LINE" | sed -n 's/.* \(--.*\)/\1/p')
                    
                    if [ -n "$extracted" ]; then
                        echo "$extracted" >> "$OUTPUT_FILE"
                        STRATEGIES_FOUND=$((STRATEGIES_FOUND + 1))
                        
                        # Выводим статус в stderr, чтобы не мешать основному выводу
						echo
                        echo "=== Найдено стратегий: $STRATEGIES_FOUND/$MAX_STRATEGIES ===" >&2
                        echo
                        if [ $STRATEGIES_FOUND -ge $MAX_STRATEGIES ]; then
                            echo "=== Достигнут лимит! Завершаю работу. ===" >&2
                            export STRATEGIES_FOUND
                            pkill -INT blockcheck.sh 2>/dev/null
                            sleep 1
                            
                            echo >&2
                            echo "=== НАЙДЕННЫЕ СТРАТЕГИИ: ===" >&2
                            cat "$OUTPUT_FILE" >&2
                            
                            exit 0
                        fi
                    fi
                    ;;
            esac
        fi
        
        # Сохраняем текущую строку как предыдущую для следующей итерации
        PREVIOUS_LINE="$line"
    done
}

# Подсчитываем количество строк в файле
FINAL_COUNT=0
if [ -f "$OUTPUT_FILE" ]; then
    FINAL_COUNT=$(wc -l < "$OUTPUT_FILE" 2>/dev/null | tr -d '[:space:]')
    if [ -z "$FINAL_COUNT" ]; then
        FINAL_COUNT=0
    fi
fi



# Код после завершения
echo
echo "=== КОНЕЦ ==="
echo

exit 0

echo "=== Итог: найдено стратегий: ${FINAL_COUNT}==="
if [ -s "$OUTPUT_FILE" ]; then
    echo "=== Результаты: ==="
    cat "$OUTPUT_FILE"
fi
