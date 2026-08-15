---
name: openwrt-vpn-gateway
version: 1.0.0
description: "Use when OpenWrt-роутер как VPN-гейтвей: выбор,"
critic_status: done
tags: [openwrt, vpn, sing-box, vless, reality, mt7981, filogic, cudy, router]
---

# OpenWrt Router as VPN Gateway (VLESS+Reality / sing-box)

## Когда использовать

- Пользователь хочет весь домашний трафик через VLESS+Reality (или другой
  прокси), а роутер (Keenetic и т.п.) нативно это не умеет
- Нужно выбрать OpenWrt-совместимый роутер под VPN (MT7981/Filogic 820 —
  300-500 Мбит/с) или mini-PC-гейтвей
- Прошивка/настройка роутера на OpenWrt как прозрачного прокси-шлюза

## Ключевое правило общения с пользователем (коррекция 08.2026 — жёсткая)

- НЕ выполнять длинные серии tool-вызовов молча: пользователь не видит
  промежуточные результаты и злится («ты достал молча действовать»,
  «ничего не выводишь в чат»).
- ПЕРЕД каждым шагом — 1-2 предложения простым языком (что делаю и зачем),
  после — короткий итог.
- НЕ сыпать жаргоном: пользователь прямо сказал «я техническую информацию
  НЕ ПОНИМАЮ». Объяснять аналогиями (дверь/замок, мозг роутера).
- Чётко разделять: действия пользователя (физические: переключить кабель,
  нажать кнопку — нумерованный список без жаргона) и мои действия.
- Всё, что можно сделать самому — делать самому.

## Текущая схема дома (08.2026, dkolchin)

- Cudy WR3000S v1 = главный роутер: LAN 192.168.10.1 (не 192.168.1.1!),
  WAN PPPoE (логин M570795), WiFi Cudy-B014 / Cudy-B014-5G (пароль
  31122009), SSH root / 1qsxdrgb
- VPN: sing-box tun → VLESS+Reality → 45.134.15.185:443 (сервер 185 —
  дефолт флота; vdska 5.39.255.242 мёртв, не использовать)
- Keenetic (192.168.1.1) → в режим точки доступа
- Рабочий комплект файлов: /root/cudy-wr3000s-kit/

Ключевой факт: KeeneticOS не умеет VLESS/Reality нативно (только WG/AWG/OpenVPN/
IPsec/PPTP/L2TP/SSTP). Пути: (а) клиент на устройстве, (б) Entware+sing-box на
самом Keenetic (CPU-потолок ~15-25 Мбит/с на MT7621), (в) OpenWrt-роутер или
mini-PC как шлюз — этот скилл про (в).

## Выбор железки (MT7981 / Filogic 820)

Проверенные на 08.2026 кандидаты (OpenWrt-поддержка подтверждена wiki):

| Модель | ОЗУ | Особенности | Цена (DNS, 08.2026) |
|--------|-----|-------------|---------------------|
| Cudy WR3000S v1 | 256 МБ | OpenWrt-сборки от вендора, 5×GbE, 2.5G uplink | 4 999 ₽ |
| Xiaomi Mi Router AX3000T | 128 МБ | дешевле, но установка через разблокировку загрузчика (X-MePatch) | 4 799 ₽ |
| GL.iNet GL-MT3000 (Beryl AX) | 512 МБ | OpenWrt из коробки, 2.5G, дорого | ~17 300 ₽ |

- MT7981B = Cortex-A53 1.3 ГГц, aarch64 → бинарник sing-box **linux-arm64**.
- Критерии выбора: ОЗУ >=256 МБ (128 МБ впритык для sing-box), возможность
  прошивки без UART (вендорские OpenWrt-образы), 2.5G-порт желателен.
- Не брать: MT7621 (MIPS, тот же потолок 15-25 Мбит/с, что у Keenetic),
  Wi-Fi 7 BE-роутеры (OpenWrt нет/сыро), Netcraze и прочие OEM-ребрендинги.
- mini-PC-вариант: N100 (Trigkey G4 ~23 000 ₽, Beelink S12 Pro — офиц. RU
  завышает до 50 000 ₽, реальная розница 18-25 тыс), б/у тонкий клиент
  (HP T630 — GX-420CA с AES-NI; Intel J1800/J1900 без AES-NI не брать).

## Прошивка OpenWrt (проверено 08.2026, Cudy 2.4.6 RU)

1. Скачать с downloads.openwrt.org (release → targets/mediatek/filogic):
   `cudy_wr3000s-v1-*-initramfs-kernel.bin` + `-squashfs-sysupgrade.bin`.
   **Проверить SHA256** (grep из sha256sums | sha256sum -c -).
2. Сток Cudy 2.4.6 (LuCI-база) — особенности доступа:
   - логин: hidden (_csrf, token, salt), username=admin (не root!),
     пароль = sha256(sha256(pwd+salt)+token) — как в sysauth.js;
   - веб-пароль ≠ пароль WiFi (у пользователя WiFi 31122009, админка своя);
   - после неудачных логинов GET /cgi-bin/luci/ → 403 (лок по IP):
     curl мёртв, браузер жив;
   - стандартные /admin/system/flash и /flashops → 404 (удалены);
     кастомный модуль /admin/system/upgrade (двухшаговый upload→Proceed).
3. **Официальный OpenWrt образ стоковый UI НЕ ПРИНИМАЕТ**: «File is
   invalid» на загрузке (проверка Cudy-магии 0100 64aa... в заголовке).
4. **Рабочий путь — подписанный Cudy-промежуточный** (cudy_wr3000s-v1-
   sysupgrade_*.bin из общего Google Drive «Cudy Intermediary OpenWRT
   Firmware» → «WR3000S 1.0.zip», сверить MD5 на экране подтверждения):
   - загрузка через веб-UI проходит, НО scripted-заливка (fetch/curl)
     падает на Proceed: в системном логе «upgrade: Image metadata not
     present», роутер откатывается на сток;
   - **РУЧНАЯ заливка пользователем через браузер работает**. Файл на
     рабочий стол + простая инструкция — и пусть жмёт сам.
5. После промежуточного: OpenWrt 23.05-SNAPSHOT-CUDY, Wi-Fi выключен
   (работать по кабелю), LAN по умолчанию 192.168.1.1 → сразу поменять на
   192.168.10.1 (конфликт с Keenetic!). SSH: root (пароль задать).
6. Чистая OpenWrt: SSH → scp sysupgrade → `sysupgrade /tmp/img.bin`
   **БЕЗ -n** — keep settings сохраняет LAN-IP и root-пароль (миграция
   23.05→25.12.5 проверена, работает).
7. Базовая настройка: WAN = DHCP или PPPoE (`uci set network.wan.proto=
   'pppoe'` + username/password + commit + restart).
8. UART+TFTP (метод wiki) — только запасной вариант, когда веб-путь не
   сработал: CH340 3.3V, tftpd64, PC 192.168.1.88, Reset → U-Boot →
   `tftpboot 0x46000000 cudy3000s.bin; bootm 0x46000000`.

## Установка sing-box на OpenWrt

sing-box **отсутствует в официальном packages feed** (проверено 25.12.5,
mediatek_filogic) — ставить бинарником:

1. `opkg update && opkg install kmod-tun ca-bundle` (tun обязателен).
2. Скачать с GitHub `sing-box-<ver>-linux-arm64.tar.gz` (проверять версию
   `sing-box version` на клиенте, чтобы совпадала), распаковать в /usr/bin.
3. Конфиг: `/etc/sing-box/config.json` — tun-режим, см.
   `templates/sing-box-openwrt-tun.json`. Параметры Reality брать 1-в-1 из
   рабочего клиентского конфига (WSL /etc/sing-box/config-*.json) — не
   выдумывать.
4. Автозапуск: procd-скрипт `/etc/init.d/sing-box` (START=95):
   `procd_set_param command /usr/bin/sing-box run -c /etc/sing-box/config.json`,
   `procd_set_param respawn 3600 5 5`, enable + start.
5. Проверка: `wget -qO- https://api.ipify.org` → IP VPS; `pgrep -x sing-box`;
   `logread | grep -i singbox`.

## Переключение дома

Старый роутер (Keenetic) в режим точки доступа: отключить DHCP, сменить LAN IP
на свободный (192.168.1.2), WAN-порт старого роутера в LAN нового. DNS всего
дома через туннель: `uci add_list dhcp.@dnsmasq[0].server='1.1.1.1'` + restart.

## Подсети пересеклись (два роутера на 192.168.1.x)

- Симптом: на 192.168.1.1 отвечает старый роутер (KeeneticOS Web Panel),
  новый OpenWrt недоступен — Windows маршрутизирует по WiFi.
- Лечение: новому роутеру сменить LAN на 192.168.10.1 (Network →
  Interfaces → LAN → IPv4), кабель ноутбука переподключить (renew DHCP).
  Wi-Fi ноутбука можно не выключать (старый роутер продолжает раздавать
  интернет, пока кабель провайдера не переключён).
- Диагностика: Get-NetIPConfiguration / Find-NetRoute 192.168.1.1 /
  arp -a (искать MAC нового роутера).

## CORS-трюк: загрузка файла в веб-морду роутера из браузера

file-input программно не заполнить, curl-сессия часто лочится. Решение:
Python HTTP-сервер на WSL с `Access-Control-Allow-Origin: *`
(scripts/cors-server.py) → браузер с авторизованной сессией fetch'ит файл
(http://<WSL-IP>:8000/...) и POST'ит FormData в upgrade-эндпоинт роутера.
Работало на стоковом Cudy upgrade: шаг 1 FormData
{cbid.upgrade.1.firmware.upload=true, cbid.upgrade.1.firmware=<file>} →
ответ с MD5; шаг 2 Proceed {token, timeclock, cbi.submit=1,
cbid.upgrade.1.proceed=Proceed}.

## Серийник

S/N 2543+ = новая флеш-память → только OpenWrt ≥24.10.5. У пользователя
S0007084261208266 (старая) — подходит любой образ. Проверять наклейку до
выбора образа.

## Pitfalls

- **Формат DNS в sing-box 1.12+ (бил на 1.13.11)**: legacy
  `{"address": "tls://1.1.1.1"}` → FATAL `legacy DNS servers is deprecated...`
  Новый формат: `{"type": "tls", "tag": "remote", "server": "1.1.1.1",
  "server_port": 853}`. Всегда `sing-box check -c` после правок.
- tun-конфиг: `auto_route: true`, `strict_route: false`, `stack: system`;
  в route добавить правило `ip_cidr: [IP_VPS/32] → direct` (защита от петли).
- **Аппаратный оффлоадинг конфликтует с tun**: если скорость проседает —
  `uci set firewall.@defaults[0].flow_offloading='0'` и `_hw='0'`.
- Скриптовая заливка в кастомный прошивочный модуль Cudy ненадёжна: при
  «Image metadata not present» / откате на сток — отдать пользователю
  ручной шаг через браузер (файл на рабочий стол + простая инструкция).
- `sysupgrade` без `-n` сохраняет LAN-IP и root-пароль (это нужно); `-n`
  только для полного сброса.
- После перепрошивки Wi-Fi выключен — работа только по кабелю; ноутбук
  подключать кабелем заранее.
- Согласовывать переключение кабеля провайдера: пока он в старом роутере,
  семья сидит на его WiFi; WiFi нового роутера включать ДО переключения.
- LAN не видит интернет, а роутер видит → добавить singtun в зону wan:
  `uci add_list firewall.@zone[1].network='singtun'`.
- PPPoE: MSS clamping OpenWrt ставит сам; при проблемах mtu=1492.
- Проверка «нет процессов»: `pgrep -x sing-box`, не `-f` (ложный матч на
  собственную командную строку).
- Перед покупкой железки сверять цену в DNS города (наличие различается) —
  рецепт ценовых проверок: скилл e-commerce-pricing.

## Файлы

- `templates/sing-box-openwrt-tun.json` — проверенный tun-конфиг (1.13.x).
- `references/cudy-wr3000s-case.md` — кейс 08.2026: железо из boot-логов,
  процедура прошивки, сравнение с Xiaomi AX3000T, рабочий комплект
  /root/cudy-wr3000s-kit (прошивка 25.12.5 + sing-box 1.13.11 + README).
- `references/cudy-stock-flash-details.md` — сток 2.4.6 RU: логин-механика,
  ошибки прошивочного модуля, рабочая последовательность флеша.
- `scripts/cors-server.py` — CORS HTTP-сервер (раздача файлов в браузерную
  сессию роутера).

## Связанные скиллы

- wsl-vpn-on-demand — клиентский sing-box в WSL (параметры Reality, обёртки)
- sing-box-server-setup — серверная сторона (sb.sh, ключи Reality)
- keenetic-router-admin — старый роутер в режим точки доступа
