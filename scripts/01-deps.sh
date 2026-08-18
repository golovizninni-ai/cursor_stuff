#!/usr/bin/env bash
# Пакеты Ubuntu LTS + MySQL + пользователь БД.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

log "Установка пакетов сборки"
$SUDO apt-get update
$SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y \
  git cmake make gcc g++ clang \
  libssl-dev libbz2-dev libreadline-dev libncurses-dev libboost-all-dev \
  lsb-release gnupg wget unzip python3 rsync screen tmux curl ca-certificates \
  pkg-config

if ! dpkg -s libmysqlclient-dev >/dev/null 2>&1 && ! dpkg -s default-libmysqlclient-dev >/dev/null 2>&1; then
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y default-libmysqlclient-dev || true
fi

install_mysql() {
  if command -v mysqld >/dev/null 2>&1 || command -v mysql >/dev/null 2>&1; then
    log "MySQL уже установлен"
    return
  fi
  log "Установка MySQL"
  if $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server libmysqlclient-dev; then
    return
  fi
  log "Пробуем MySQL APT (8.4 LTS)"
  export MYSQL_APT_CONFIG_VERSION="${MYSQL_APT_CONFIG_VERSION:-0.8.36-1}"
  wget -q "https://dev.mysql.com/get/mysql-apt-config_${MYSQL_APT_CONFIG_VERSION}_all.deb" -O /tmp/mysql-apt-config.deb
  $SUDO DEBIAN_FRONTEND=noninteractive dpkg -i /tmp/mysql-apt-config.deb || true
  $SUDO apt-get update
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server libmysqlclient-dev
}

install_mysql
$SUDO systemctl enable --now mysql || $SUDO systemctl enable --now mysqld || true

ensure_mysql_password
log "Создание пользователя MySQL ${MYSQL_USER}"
mysql_root <<SQL
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASS}';
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PASS}';
ALTER USER '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASS}';
ALTER USER '${MYSQL_USER}'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PASS}';
GRANT ALL PRIVILEGES ON \`ac\_%\`.* TO '${MYSQL_USER}'@'localhost';
GRANT ALL PRIVILEGES ON \`ac\_%\`.* TO '${MYSQL_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL

CNF="/etc/mysql/conf.d/azerothcore-bots.cnf"
if [[ ! -f "$CNF" ]]; then
  log "Тюнинг MySQL"
  $SUDO tee "$CNF" >/dev/null <<'EOF'
[mysqld]
skip-log-bin
innodb_buffer_pool_size = 4G
innodb_io_capacity = 500
innodb_io_capacity_max = 2500
transaction_isolation = READ-COMMITTED
max_connections = 200
EOF
  $SUDO systemctl restart mysql || $SUDO systemctl restart mysqld || true
fi

mkdir -p "$AC_ROOT" "$AC_DATA"
log "Готово. Пароль MySQL: $AC_ROOT/mysql-password"
