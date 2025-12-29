#!/bin/ash
echo 1
ZAPRET_FOLDER=${ZAPRET_FOLDER:-"/opt/zapret_orig"}
MAX_STRATEGIES=${MAX_STRATEGIES:-5}
OUTPUT_FILE=${OUTPUT_FILE:-/tmp/resscan/final.txt}

STRATEGIES_FOUND=0
PREVIOUS_LINE=""

: > "$OUTPUT_FILE"

echo
echo "=== Запуск blockcheck с лимитом найденных стратегий: $MAX_STRATEGIES ==="
echo

sleep 3

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
						echo
                        echo "=== Найдено стратегий: $STRATEGIES_FOUND/$MAX_STRATEGIES ===" >&2
                        echo
						
                        if [ $STRATEGIES_FOUND -ge $MAX_STRATEGIES ]; then
                            echo
							echo "=== Достигнут лимит поиска. Завершаю работу. ===" >&2
                            echo
							export STRATEGIES_FOUND
                            pkill -INT blockcheck.sh #2>/dev/null
							killall blockcheck.sh
							for pid in $(ps | grep blockcheck.sh | grep -v grep | cut -d' ' -f2); do kill $pid; done
                            sleep 100
                            
                            echo >&2
                            echo
							echo "=== НАЙДЕННЫЕ СТРАТЕГИИ: ===" >&2
                            echo
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

echo
echo "=== КОНЕЦ ПОИСКА СТРАТЕГИЙ ==="
echo
exit 0

# Код после завершения
echo
echo "=== Итог: найдено ${FINAL_COUNT} стратегий ==="
if [ -s "$OUTPUT_FILE" ]; then
    echo "=== Результаты: ==="
    cat "$OUTPUT_FILE"
fi
