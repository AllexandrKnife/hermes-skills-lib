---
name: openwrt-singbox-gateway
version: 1.0.0
description: "Use when OpenWrt-гейтвей: sing-box VLESS/Reality,"
critic_status: done
---

# OpenWrt + sing-box gateway (домашний VLESS/Reality-шлюз)

## Когда использовать
- Весь домашний трафик через VLESS+Reality (или другой прокси-протокол) на роутере
- KeeneticOS не умеет VLESS нативно (только WG/AWG/OpenVPN/IPsec/PPTP/L2TP/SSTP) — нужен OpenWrt-роутер или mini-PC-гейтвей
- Выбор железа под OpenWrt, прошивка Cudy WR3000S, установка sing-box на OpenWrt

## Выбор железа (цены DNS, 08.2026)
| Модель | Чип | ОЗУ | Цена | Комментарий |
|---|---|---|---|---|
| Cudy WR3000S v1 | MT7981B 1.3 ГГц | 256 МБ DDR3 | 4 999 ₽ | OpenWrt wiki + офиц. сборки; 1x2.5G + 4x1G; ARM64 |
| Xiaomi AX3000T | MT7981B | 128 МБ | 4 799 ₽ | OpenWrt ставится через разблокировку загрузчика (X-MePatch) |
| GL.iNet GL-MT3000 | MT7981B | 512 МБ | 17 300 ₽ | OpenWrt от вендора, 2.5G, дорого |
- MT7981 (Filogic 820) гонит sing-box/WG 300-500 Мбит/с. MT7621 (Keenetic, ASUS RT-AX53U/RT-AX1800U, Netcraze Start и т.п.) — потолок 15-25 Мбит/с.
- Не брать: OEM-ребрендинги (Netcraze — неизвестные чипсеты, OpenWrt нет), Wi-Fi 7 (поддержки OpenWrt нет/сырая), Keenetic (нет VLESS).
- Mini-PC-альтернатива: N100 (Trigkey G4 от 23 000 ₽ — проверено; Beelink S12 Pro 50 504 ₽ — офиц. RU-магазин, завышен), б/у тонкие клиенты с AES-NI (HP T630 GX-420CA — ок; Intel J1800/J1900 без AES-NI — не брать).

## Прошивка Cudy WR3000S
1. Образы: downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/
   - `cudy_wr3000s-v1-initramfs-kernel.bin` — временный (TFTP/веб-заливка)
   - `cudy_wr3000s-v1-squashfs-sysupgrade.bin` — постоянный (sysupgrade)
   - SHA256 сверять с sha256sums в той же папке
2. Сток Cudy 2.4.x — на базе LuCI (корень редиректит на /cgi-bin/luci/), SSH закрыт (22 refused), веб 80/443 открыт. Логин — только пароль (механика — ниже, раздел «Логин в Cudy-LuCI»).
3. Путь 1 — БЕЗ UART (проверено 08.2026 до шага заливки; гайд lsetc.ru 11.2025):
   - Официальный OpenWrt-образ сток ОТКЛОНЯЕТ: ответ «File is invalid» (проверено 08.08.2026 — апгрейд-модуль проверяет подпись).
   - Нужен ПОДПИСАННЫЙ Cudy-образ: `cudy_wr3000s-v1-sysupgrade_20251119.bin` (14.9 МБ) из папки Cudy на Google Drive (id папки/файла, sha256 — в references/cudy-wr3000s-kit-2026-08.md).
   - Заливка: «Общие настройки → Прошивка → Локальное обновление» (или POST на /cgi-bin/luci/admin/system/upgrade полями token/timeclock/cbi.submit/cbid.upgrade.1.firmware — см. «Загрузка файла через браузер»).
   - После перезагрузки — OpenWrt на 192.168.1.1 (root, пустой пароль), Wi-Fi ВЫКЛЮЧЕН: дальше только КАБЕЛЕМ. Затем Система → Восстановление/Обновление → официальный squashfs-sysupgrade.bin, СНЯТЬ «Сохранить настройки».
   - ВНИМАНИЕ (11.2025+): серийники 2543+ — новая флеш-память, нужен OpenWrt 24.10.5+ (подписанный образ 19.11.2025 уже поддерживает).
4. Путь 2 (fallback, wiki: UART+TFTP): USB-UART 3.3V CH340/CP2102 + TFTP-сервер на ПК с IP 192.168.1.88:
   - U-Boot shell: питание + держать Reset
   - файл переименовать в `cudy3000s.bin`
   - `tftpboot 0x46000000 cudy3000s.bin; bootm 0x46000000`
   - затем scp sysupgrade → `sysupgrade -n`
5. После загрузки OpenWrt: 192.168.1.1, ssh root (без пароля), `passwd`, WAN (DHCP или PPPoE).

## Логин в Cudy-LuCI (сток 2.4.x)

НЕ стандартный LuCI-POST. Форма логина: hidden `_csrf`, `token`, `salt`,
`luci_username=admin` (значение в hidden-поле — это admin, НЕ root), `zonename`,
`timeclock`; видимое поле `#luci_password2`. JS (sysauth.js) считает:
`luci_password = sha256( sha256(pwd + salt) + token )`.

Pitfall: curl против Cudy-вебморды — GET отдаёт 403 (анти-бот), после нескольких
неудачных POST — временный лок по IP. Браузер с JS проходит всегда. Вход ТОЛЬКО
через реальный браузер: в browser_console страницы
`pw.value='...'; document.querySelector('form').requestSubmit()` — sysauth.js сам
заполнит хэш и скрытые поля. Снапшот-тул может не показывать модалку логина
(Bootstrap #cbi-modal-auth) — проверять DOM через browser_console.

## Загрузка файла в веб-форму роутера через браузер

Файловый input нельзя заполнить JS, а curl к вебморде блокируется. Рабочий паттерн:
1. WSL: поднять `scripts/cors-server.py` (python, раздаёт файлы с
   `Access-Control-Allow-Origin: *`) — `terminal(background=true)`.
2. В браузерной консоли авторизованной сессии:
   `const b = await (await fetch('http://<wsl-ip>:8000/<file>')).blob();`
   `fd.append('<field>', new File([b], '<name>', {type:'application/octet-stream'}));`
   `await fetch('<action>', {method:'POST', body: fd, credentials:'include'})`
3. Разбор ответа: «File is invalid» = модуль отклонил по подписи (нужен подписанный
   образ); иной ответ — успех/другая ошибка.
Поля формы апгрейда Cudy: token, timeclock, cbi.submit=1, cbi.rlf.1.firmware,
cbid.upgrade.1.firmware (файл). Action: /cgi-bin/luci/admin/system/upgrade.
Свежий token брать fetch-ом страницы формы в той же сессии.

## Установка sing-box (в официальном packages feed sing-box/xray НЕТ — вручную)
```sh
opkg update && opkg install kmod-tun ca-bundle
tar -xzf sing-box-1.13.11-linux-arm64.tar.gz -C /tmp   # ARM64! не amd64 как в WSL
cp /tmp/sing-box-1.13.11-linux-arm64/sing-box /usr/bin/sing-box
cp config.json /etc/sing-box/config.json
cp sing-box.init /etc/init.d/sing-box && chmod +x /etc/init.d/sing-box
/etc/init.d/sing-box enable && /etc/init.d/sing-box start
wget -qO- https://api.ipify.org   # должен показать IP сервера туннеля
```
- procd-скрипт: START=95, `command sing-box run -c /etc/sing-box/config.json`, respawn.
- Проверка конфига всегда: `/usr/bin/sing-box check -c /etc/sing-box/config.json`.

## tun-конфиг — весь дом через туннель без прокси на устройствах
Шаблон: `templates/openwrt-tun-config.json` (сервер 185; смена сервера — sed, см. references).
Ключевые поля: inbound type=tun (interface_name singtun, address 172.19.0.1/30, auto_route=true, strict_route=false, stack=system), dns remote через туннель, route.final=vless, auto_detect_interface=true, правило `ip_cidr <VPS_IP>/32 → direct` (защита от петли).

## Смена сервера туннеля
sed по /etc/sing-box/config.json (server, uuid, public_key, short_id, при необходимости server_port), затем `/etc/init.d/sing-box restart`. Всегда `sing-box check` после sed. Готовые команды и параметры флота — `references/cudy-wr3000s-kit-2026-08.md`.

## Pitfalls
- **sing-box >=1.12: DNS-серверы в НОВОМ формате** `{"type":"tls","server":"1.1.1.1","server_port":853}`. Legacy `"address":"tls://..."` → FATAL "legacy DNS servers is deprecated... set ENABLE_DEPRECATED_LEGACY_DNS_SERVERS=true". Конфиг, валидный на старых версиях, падает на новых.
- Домашний DNS: dnsmasq форвардит на провайдерский DNS напрямую (мимо туннеля) → `uci add_list dhcp.@dnsmasq[0].server='1.1.1.1'` + restart dnsmasq.
- flow offloading (hwnat) конфликтует с tun → `uci set firewall.@defaults[0].flow_offloading='0'` (+ `_hw`), restart firewall.
- LAN не ходит через tun: `uci add_list firewall.@zone[1].network='singtun'` (zone[1]=wan), restart firewall.
- PPPoE: `uci set network.wan.proto='pppoe'` + username/password; MSS clamp автоматический.
- Верификация egress: WSL/роутер могут ходить через другой туннель — проверять фактический egress IP, не доверять «должно быть».
- Нестандартный порт сервера (напр. 87:62832) — маскировка хуже, для домашнего шлюза только как запасной.
- curl против вебморды Cudy: 403/лок — не ретраить, сразу браузер (см. «Логин в Cudy-LuCI»).
- После промежуточного Cudy-образа Wi-Fi выключен и адрес 192.168.1.1 — спрашивать пользователя про КАБЕЛЬ до прошивки.
- `pkill -f gdown` убивает собственную команду (в её командной строке есть слово gdown) — не использовать.
- Проверка подписи апгрейда: «File is invalid» в ответе формы = образ не подписан Cudy.

## Support files
- `templates/openwrt-tun-config.json` — рабочий tun-конфиг (сервер 185)
- `scripts/cors-server.py` — CORS-сервер для загрузки файлов в веб-формы роутера через браузер
- `scripts/install-singbox-openwrt.sh` — установка sing-box на роутер одной командой (opkg+бинарник+конфиг+init)
- `references/cudy-wr3000s-kit-2026-08.md` — состояние работ, параметры флота, sed-команды, проверенные факты прошивки

## Связанные скиллы
- wsl-vpn-on-demand — sing-box-клиент на WSL (mixed), флот серверов
- sing-box-server-setup — серверная часть на VPS (sb.sh)
- keenetic-router-admin — если остаётся Keenetic (AP-режим)
