#!/bin/sh
# Установка sing-box на OpenWrt (mediatek/filogic, ARM64) одной командой.
# Запускать на роутере: sh /tmp/install-singbox-openwrt.sh
# Перед запуском залить на роутер в /tmp: sing-box-*.tar.gz, config.json, sing-box.init
set -e

echo "[1/5] opkg update + kmod-tun + ca-bundle..."
opkg update
opkg install kmod-tun ca-bundle

echo "[2/5] распаковка бинарника..."
mkdir -p /usr/bin /etc/sing-box
tar -xzf /tmp/sing-box-1.13.11-linux-arm64.tar.gz -C /tmp
cp /tmp/sing-box-1.13.11-linux-arm64/sing-box /usr/bin/sing-box
chmod +x /usr/bin/sing-box

echo "[3/5] конфиг + init-скрипт..."
cp /tmp/config.json /etc/sing-box/config.json
cp /tmp/sing-box.init /etc/init.d/sing-box
chmod +x /etc/init.d/sing-box

echo "[4/5] проверка конфига..."
/usr/bin/sing-box check -c /etc/sing-box/config.json

echo "[5/5] автозапуск + старт..."
/etc/init.d/sing-box enable
/etc/init.d/sing-box start
sleep 3

echo "--- версия:"
/usr/bin/sing-box version | head -1
echo "--- процесс:"
pgrep -x sing-box && echo "sing-box работает" || echo "sing-box НЕ запущен!"
echo "--- внешний IP через туннель:"
wget -qO- https://api.ipify.org
echo ""
echo "Готово. IP должен совпадать с IP сервера туннеля (напр. 45.134.15.185)."
