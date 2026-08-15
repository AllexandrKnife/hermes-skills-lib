# sb.sh (yonggekkk/sing-box-yg) — интерактивный флоу установки

Версия: v26.4.11 (проверено 08.2026, Ubuntu 22.04, свежий VPS). Скрипт меню «0-16», китайский интерфейс по умолчанию.

## Транскрипт промптов (ответы жирным)

Этап зависимостей (apt):
1. `Configuring iptables-persistent — Save current IPv4 rules? [yes/no]` → **no**
2. `Save current IPv6 rules? [yes/no]` → **no**
3. `needrestart — Which services should be restarted?` (список 1-9) → **9** (none of the above)
   — всплывает ПОСЛЕ КАЖДОГО батча apt (iptables-persistent, tzdata, expect…), отвечать заново
4. `tzdata — Geographic area:` → **8** (Europe); `Time zone:` → **7** (Berlin)

Меню скрипта:
5. `请输入数字【0-16】` (VPS-статус: система/ядро/IP/регион/sing-box статус) → **1** (установка)
6. `是否开放端口，关闭防火墙？` (открыть порты/снять фаервол) → **1** (да, дефолт)
7. `使用哪个内核版本？` (kernel) → **1** (последний стабильный; вариант 2 = 1.10.7 с geosite/IP-преференс, без Anytls)
8. `是否申请一个Acme域名IP证书？` (ACME-серт) → **1** (самоподписанный, дефолт; ACME не нужен для Reality)
9. `设置各个协议端口` (порты) → **1** (авто-случайные 10000-65535)

Финал: печатает share-ссылки (vless-reality / vmess / hysteria2 / tuic / anytls), скрипт завершается (SSH-сессия закрывается).

## Артефакты после установки
- /usr/bin/sb — сам скрипт (самоустанавливается; меню перезапускается командой `sb`)
- /etc/s-box/sb.json — рабочий конфиг (ExecStart: /etc/s-box/sing-box run -c /etc/s-box/sb.json)
- /etc/s-box/sb10.json, sb11.json, sbox.json — снапшоты конфигов
- /root/geoip.db, geosite.db, sbyg_update — базы и маркер обновления
- sing-box.service — systemd, enabled, активен сразу

## Порты по умолчанию (авто-генерация, v26.4.11 на vdska)
- VLESS-Reality: 22524 TCP (SNI apple.com, flow xtls-rprx-vision)
- mixed (2082) TCP — служебный
- Hysteria2: 42954 UDP (SNI www.bing.com, pinSHA256)
- TUIC: 60240 UDP (SNI www.bing.com)
- Anytls: 56799 TCP

Проверка слушающих портов без `ss`: /proc/net/tcp + /proc/net/udp
(awk '{split($2,a,":"); port=strtonum("0x"a[2]); if (port>1000 && $4=="0A") print port}').
UDP-порты hy2/tuic в /proc/net/tcp НЕ видны — смотреть /proc/net/udp.

## Русская версия скрипта
- Источник: /usr/bin/sb на VPS 45.134.15.185 (sha256 bbf9c98d3e1f9d96ed3c127b54014d9680969bfb903a6a94c3388a0a306e687e, ~156 КБ, меню на русском «Установка необходимых зависимостей…»)
- Китайская версия: ~149 КБ, ставится по умолчанию
- Замена: см. SKILL.md раздел 2 (pipe VPS→VPS, бэкап .bak.cn)
