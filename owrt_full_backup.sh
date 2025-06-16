#!/bin/sh
# Очистка и создание SMB-шары
ksmbd.addshare -d $SHARE_NAME 2>/dev/null

ksmbd.addshare -a $SHARE_NAME  -o 'path='$ARCHIVE_DIR -o 'browseable=yes' -o 'writeable=yes' -o 'read only = no' -o 'guest ok = yes' -o 'directory mask = 0777' -o 'create mask = 0666'

chmod 0777 /etc/ksmbd/ksmbd.conf
/etc/init.d/ksmbd restart
sleep 3

clear

ARCHIVE_USER="archive"
PASSWORD="$ARCHIVE_USER"
ARCHIVE_DIR="/tmp/archive/"
ARCHIVE_FILE=$ARCHIVE_DIR"full_RouteRich_backup_$(date +'%Y-%m-%d_%H-%M').tar"
SHARE_NAME="archive"

# Цвета (для ash через printf)
YELLOW='\033[1;33m'
NC='\033[0m'

# Проверка и запуск службы ksmbd
/etc/init.d/ksmbd status >/dev/null 2>&1 || {
    echo "▶️ Запускаю ksmbd..."
    /etc/init.d/ksmbd start
    /etc/init.d/ksmbd enable
}

echo "📁 Создаю директорию $ARCHIVE_DIR..."
mkdir -p "$ARCHIVE_DIR"
chmod 0777 "$ARCHIVE_DIR"

# echo ${ARCHIVE_FILE}

echo "🗃️ Создание архива /overlay в $ARCHIVE_FILE..."
tar -cvhpf "$ARCHIVE_FILE" /overlay >/dev/null 2>&1

# Создание пользователя (повторный запуск скрипта не вызовет ошибку)
#ksmbd.adduser -a "$ARCHIVE_USER" -p "$PASSWORD" 2>/dev/null

# Создаём "классический" архив системы с добавлением каталога /etc (полностью)
grep -qxF '/etc' /etc/sysupgrade.conf || echo '/etc' >> /etc/sysupgrade.conf
sysupgrade -b "${ARCHIVE_DIR}backup-RouteRich-$(date +'%Y-%m-%d').tar.gz"

# Получение IP и hostname
IP=$(ip -4 addr show br-lan | awk '/inet / {print $2}' | cut -d/ -f1)
HOST=$(uci get system.@system[0].hostname)

# Вывод итогов
printf "\n✅ ${YELLOW}Готово! Архив доступен по адресам"; echo; echo
printf "${YELLOW}\\\\\\\\%s\\\\%s${NC}\n" "$IP" "$SHARE_NAME"
printf "${YELLOW}\\\\\\\\%s.lan\\\\%s${NC}\n" "$HOST" "$SHARE_NAME"
echo
echo
