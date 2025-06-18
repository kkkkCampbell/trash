#!/bin/sh
#FULL_BACKUP

clear
echo Создаём архив. Пожалуйста, подождите две минуты, процесс идёт...
echo =================================================================

SYS_ARCHIVE_FILENAME="backup-RouteRich-$(date +'%Y-%m-%d_%H-%M')"
SHARE_NAME="archive"
OUTPUT_DIRECTORY="/tmp/archive/"

# Цвета
YELLOW='\033[1;33m'
NC='\033[0m'

mkdir -p $OUTPUT_DIRECTORY
chmod 777 $OUTPUT_DIRECTORY

# Создаём костыль, формирующий при каждой загрузке системы директорию /tmp/archive
# echo -e '#!/bin/sh /etc/rc.common\n\nSTART=99\n\nboot() {\n    mkdir -p /tmp/archive && chmod 0777 /tmp/archive\n}' > /etc/init.d/mkarchive
# chmod +x /etc/init.d/mkarchive
# /etc/init.d/mkarchive disable

echo Копируем overlay
# Создаём временные папки для архивации
mkdir -p /tmp/backup_staging
mkdir -p /tmp/backup_staging/overlay
# Копируем во временную папку каталог /overlay
cp -r /overlay /tmp/backup_staging/
# Из каталога /overlay/upper удаляем run и  work
rm -rf /tmp/backup_staging/overlay/upper/run
rm -rf /tmp/backup_staging/overlay/work

# Создаём итоговый архив
echo Сжимаем файлы
cd /tmp/backup_staging
tar -cvpf "$OUTPUT_DIRECTORY$SYS_ARCHIVE_FILENAME.tar" overlay >/dev/null
gzip -9 -c "$OUTPUT_DIRECTORY$SYS_ARCHIVE_FILENAME.tar" > "$OUTPUT_DIRECTORY$SYS_ARCHIVE_FILENAME.tar.gz"
rm -rf "$OUTPUT_DIRECTORY$SYS_ARCHIVE_FILENAME.tar"

echo Удаляем временные папки
# Удаляем временные папки
rm -rf /tmp/backup_staging
rm -rf /tmp/backup_staging/overlay
# Очистка и создание SMB-шары
#ksmbd.addshare -d $SHARE_NAME >/dev/null
#ksmbd.addshare -a $SHARE_NAME  -o 'path='$OUTPUT_DIRECTORY -o 'browseable=yes' -o 'writeable=yes' -o 'read only = no' -o 'guest ok = yes' -o 'directory mask = 0777' -o 'create mask = 0666' >/dev/null


# Удаляем шару
NAME="$SHARE_NAME"
INDEX=$(uci show ksmbd | grep '=share' | cut -d[ -f2 | cut -d] -f1 | while read i; do
    [ "$(uci get ksmbd.@share[$i].name)" = "$NAME" ] && echo $i && break
done)

[ -n "$INDEX" ] && uci delete ksmbd.@share[$INDEX] && uci commit ksmbd && /etc/init.d/ksmbd restart

sleep 2

echo Создаём сетевую папку
# Создаём шару
uci add ksmbd share
uci set ksmbd.@share[-1].name="$SHARE_NAME"
uci set ksmbd.@share[-1].path="$OUTPUT_DIRECTORY"
uci set ksmbd.@share[-1].guest_ok="yes"
uci set ksmbd.@share[-1].read_only="no"
uci set ksmbd.@share[-1].create_mask="0777"
uci set ksmbd.@share[-1].dir_mask="0777"
uci set ksmbd.@share[-1].inherit_owner="yes"
uci commit ksmbd
sleep 2
/etc/init.d/ksmbd restart

echo Извлекаем IP и hostname
# Получение IP и hostname
IP=$(ip -4 addr show br-lan | awk '/inet / {print $2}' | cut -d/ -f1)
HOST=$(uci get system.@system[0].hostname)

# Вывод итогов
printf "\n✅ ${YELLOW}Готово! Архив доступен по адресам"; echo; echo
printf "${YELLOW}\\\\\\\\%s\\\\%s${NC}\n" "$IP" "$SHARE_NAME"
printf "${YELLOW}\\\\\\\\%s.lan\\\\%s${NC}\n" "$HOST" "$SHARE_NAME"
echo; echo
