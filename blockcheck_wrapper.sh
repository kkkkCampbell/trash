#!/bin/ash

ZAPRET_FOLDER="/opt/zapret_orig"
MAX_STRATEGIES=${MAX_STRATEGIES:-5}
OUTPUT_FILE=${OUTPUT_FILE:-/tmp/resscan/final.txt}

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
PREVIOUS_LINE=""

: > "$OUTPUT_FILE"

echo "=== Запуск blockcheck с лимитом $MAX_STRATEGIES стратегий ==="
echo

# Основной pipeline
sh $ZAPRET_FOLDER/blockcheck.sh 2>&1 | tee /dev/tty | {
    # Переменная для хранения строки с параметрами стратегии
    strategy_line=""
    
    while read -r line; do
        # Проверяем, содержит ли строка параметры стратегии
        if echo "$line" | grep -q -E " (nfqws|tpws|dvtws|winws) "; then
            # Нашли новую стратегию - запоминаем
            strategy_line="$line"
            continue
        fi
        
        # Проверяем, есть ли запомненная стратегия для обработки
        if [ -n "$strategy_line" ]; then
            case "$line" in
                *"!!!!! AVAILABLE !!!!!"*)
                    # Стратегия сработала - извлекаем параметры
                    extracted=$(echo "$strategy_line" | sed 's/.* nfqws //;s/.* tpws //;s/.* dvtws //;s/.* winws //')
                    
                    if [ -n "$extracted" ]; then
                        echo "$extracted" >> "$OUTPUT_FILE"
                        STRATEGIES_FOUND=$((STRATEGIES_FOUND + 1))
                        
                        # Выводим статус в stderr
                        echo "=== Найдено стратегий: $STRATEGIES_FOUND/$MAX_STRATEGIES ===" >&2
                        
                        if [ $STRATEGIES_FOUND -ge $MAX_STRATEGIES ]; then
                            echo "=== Достигнут лимит! Завершаю... ===" >&2
                            export STRATEGIES_FOUND
                            pkill -INT blockcheck.sh 2>/dev/null
                            sleep 1
                            
                            echo >&2
                            echo "=== НАЙДЕННЫЕ СТРАТЕГИИ: ===" >&2
                            cat "$OUTPUT_FILE" >&2
                            
                            exit 0
                        fi
                    fi
                    # Сбрасываем запомненную строку
                    strategy_line=""
                    ;;
                    
                *"UNAVAILABLE"*)
                    # Стратегия не сработала - просто сбрасываем
                    strategy_line=""
                    ;;
            esac
        fi
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
echo "=== Итог: найдено ${FINAL_COUNT} стратегий ==="
if [ -s "$OUTPUT_FILE" ]; then
    echo "=== Результаты: ==="
    cat "$OUTPUT_FILE"
fi
