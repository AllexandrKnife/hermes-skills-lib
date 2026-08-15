# OpenWrt 25.12: apk-менеджер и LuCI на русском (08.2026)

Контекст: Cudy WR3000S, OpenWrt 25.12.5 (r33051), aarch64 (MT7981 filogic).

## Главное: на 25.12 пакетный менеджер apk, НЕ opkg

- `opkg` отсутствует: `ash: opkg: not found`, `find / -name opkg*` пусто.
- Менеджер: `/usr/bin/apk`, apk-tools 3.0.5.
- Репозитории в /etc/apk/world (список «желаемых» пакетов), feeds в /etc/apk/repositories.d (distfeeds.conf в 25.12 нет).
- install-singbox.sh из комплекта использует `opkg update && opkg install kmod-tun ca-bundle` — на 25.12 упадёт. kmod-tun на этой сборке уже в образе (tun работал без доустановки), так что для sing-box это не блокер.

## LuCI на русском — полная процедура

Симптом: включил русский в System → Language and Style → ничего не изменилось.
Причина: пакет перевода luci-i18n-base-ru не установлен. Переключатель работает только с пакетом.

1. Скачать пакет (формат .apk, каталог luci/ феда):
   https://downloads.openwrt.org/releases/25.12.5/packages/aarch64_cortex-a53/luci/luci-i18n-base-ru-26.218.70234~1654281.apk
   (78 КБ; версия пакета может отличаться — смотреть листинг каталога luci/)
2. Залить на роутер: sshpass scp ... root@192.168.10.1:/tmp/
3. Установить БЕЗ сети (роутер в WISP может не ходить в downloads.openwrt.org):
   apk add --no-network --allow-untrusted /tmp/luci-i18n-base-ru.apk
4. Если отказ «unable to select packages: curl (no such package): required by: world[curl]»:
   в /etc/apk/world лежит строка `curl` (кто-то добавил в желаемые, но пакет не установлен).
   Фикс: sed -i "/^curl$/d" /etc/apk/world, повторить apk add.
5. Включить язык и перезапустить веб:
   uci set luci.main.lang=ru
   uci commit luci
   /etc/init.d/uhttpd restart
6. В браузере Ctrl+F5 (сброс кэша), открыть http://192.168.10.1
7. Проверка файла перевода: /usr/lib/lua/luci/i18n/base.ru.lmo

## Прочие apk-заметки

- `apk add --no-network` ставит из локального файла, не трогая репозитории.
- `apk add --allow-untrusted` нужен для файла без подписи репозитория.
- Репозитории могут отдавать 404 на Packages: в 25.12 списки пакетов теперь packages.adb (не Packages.gz); 404 на старый путь — норма.
