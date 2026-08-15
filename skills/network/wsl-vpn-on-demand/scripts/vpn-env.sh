#!/bin/bash
# Экспорт прокси-переменных на ТЕКУЩУЮ сессию (после vpn-tun.sh up)
# Использование: source /usr/local/bin/vpn-env.sh
# НЕ добавлять в .bashrc — при выключенном туннеле ломает весь трафик агента.
export http_proxy=http://127.0.0.1:1080
export https_proxy=http://127.0.0.1:1080
export all_proxy=socks5://127.0.0.1:1080
export HTTP_PROXY=http://127.0.0.1:1080
export HTTPS_PROXY=http://127.0.0.1:1080
export ALL_PROXY=socks5://127.0.0.1:1080
echo "прокси экспортирован (127.0.0.1:1080)"
echo "проверка: curl -x http://127.0.0.1:1080 https://ipinfo.io/json"
echo "сброс: unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY"
