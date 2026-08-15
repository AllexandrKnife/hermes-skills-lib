---
name: linux-vps-maintenance
version: 1.0.0
description: "Use when VPS SSH: apt update/upgrade, чистка ядер."
critic_status: done
---

# Обслуживание Linux VPS по SSH

## Когда использовать

Пользователь просит подключиться к VPS, обновить (apt update/upgrade), почистить (старые ядра, autoremove, apt clean), проверить диск. Актуально для всего флота VPS пользователя — 5 хостов, все root/1qsxdrgb (реестр IP — в памяти; детальный инвентарь каждого — references/vps-fleet.md): 45.134.15.185 (sing-box+AGH+unbound), 5.39.255.242 (vdska), 204.77.1.107 (parafin, Ubuntu 24.04), 87.121.38.60 (babayka, Ubuntu 22.04), 46.30.47.120 (eurodir, Debian 12). ОС у хостов РАЗНЫЕ — не предполагать Ubuntu по умолчанию, всегда смотреть /etc/os-release.

## Шаги

1. Проверка доступности порта ДО ssh (быстро, с таймаутом):
   timeout 10 bash -c 'cat < /dev/null > /dev/tcp/<IP>/22' && echo open || echo closed

2. Подключение одной командой. Ключи обязательны: без них при переустановке VPS дрейф known_hosts ломает ssh:
   sshpass -p '<pass>' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o UserKnownHostsFile=/dev/null root@<IP> '<cmd>'

   - Все команды одного захода склеивать в ОДНУ ssh-сессию через ';' или '&&' — каждая новая ssh = новое соединение и лишний round-trip.
   - Вывод ssh содержит \r (CRLF) — это норма, не ошибка.

3. Обновление:
   Перед upgrade на критичных хостах (sing-box/AGH-шлюз) — точка возврата:
   снапшот в панели хостера ИЛИ `dpkg --get-selections > /root/dpkg-selections.bak` +
   `apt-mark showmanual > /root/manual-pkgs.bak` (откат по списку после поломки).
   apt-get update 2>&1 | tail -5
   apt-get upgrade -y 2>&1 | tail -15
   Контроль полноты: apt-get --simulate upgrade 2>/dev/null | grep -c "^Inst" → 0 = всё обновлено.

4. Решение о перезагрузке (не перезагружать вслепую):
   ls /var/run/reboot-required → файл существует = нужен reboot; нет = не нужен.
   needrestart «Service restarts being deferred» (dbus, systemd-logind и т.п.) — норма, сервисы подхватятся сами; не трогать.

5. Чистка старых ядер:
   uname -r — запомнить текущее ядро, его НИКОГДА не удалять.
   dpkg --list | grep -E "linux-image|linux-headers" | awk '{print $2, $3}' — список установленных.
   apt-get remove -y --purge linux-image-<OLD> linux-headers-<OLD> linux-headers-<OLD>-generic
   apt-get autoremove -y --purge 2>&1 | tail -3
   Проверка после autoremove: `which ip` / `ip addr` — autoremove может снести iproute2 (прецедент 08.2026); при сносе — `apt-get install -y iproute2`.
   apt-get clean
   Проверка: ls /lib/modules/ — осталась только текущая версия; ls /boot | grep vmlinuz.

6. Отчёт: df -h / | tail -1 до и после — назвать освобождённый объём.

## Инвентаризация VPS (что стоит на хосте)

Когда пользователь даёт новый IP или просит «узнай что там» — один ssh-заход на хост, команды через ';':

    hostname; . /etc/os-release; echo "$PRETTY_NAME"; uname -r; uptime
    docker ps --format '{{.Names}} | {{.Image}} | {{.Ports}}' || echo 'no docker'
    ss -tlnp | awk 'NR==1 || /LISTEN/'
    systemctl list-units --type=service --state=running --no-pager --no-legend | awk '{print $1}' | head -30
    for b in sing-box AdGuardHome unbound awg wg xray v2ray nginx caddy; do which $b >/dev/null 2>&1 && echo "$b: $(which $b)"; done
    ls /opt /srv /root; crontab -l 2>/dev/null | grep -v '^#'

- Несколько хостов — параллельными terminal-вызовами (по одному на хост); вывод чистить от «Warning: Permanently added...»: | grep -v Warning
- Миграция агентов на хосте (замена OpenClaw → Hermes с сохранением Telegram-канала) — скилл messenger-agent-migration
- sing-box (sbyg): конфиг /etc/s-box/sb.json; если путь неизвестен — systemctl cat sing-box | grep ExecStart. Протоколы/порты: jq -r '.inbounds[] | "\(.type) port=\(.listen_port)"' /etc/s-box/sb.json
- Типовой sbyg-стек: VLESS+VMess+Hysteria2+Tuic+AnyTLS, mita (11000-11005), AdGuardHome *:53 и :3000, unbound 127.0.0.1:5353, webmin 10000, fail2ban, cron «0 1 * * * systemctl restart sing-box»

## Health-check VPS (проверка состояния, 4 захода)

Порядок (проверено 11.08.2026 на 45.134.15.185):
1. Базовый статус: uptime, OS/kernel, free -h, df -h /, reboot-required, systemctl --failed, apt simulate upgrade.
2. Проблемные сервисы + раскладка диска (du -x --max-depth=1 / | sort -rh | head -12), docker ps.
3. Корневые причины: журналы упавших сервисов, детализация каталогов (/usr, /root, /var), конфиги.
4. Верификация живости: фактический резолв (nslookup), ss -tlnp по портам.

Ключевые сигналы:
- df -h / — 89%+ на диске 7.8G = тревога. Кандидаты на чистку, по убыванию выгоды:
  1. /opt/AdGuardHome/data/querylog.json — лог DNS-запросов AGH, растёт БЕЗ лимита; на 185 достиг 2.16G и забил диск в 100% (14.08.2026). Фикс: СНАЧАЛА отключить запись (enabled: false, ниже), ПОТОМ stop → rm querylog.json → start. Если удалить файл при включённом логе и рестартнуть — AGH пересоздаст его и быстро накопит заново (прецедент 14.08.2026: 201M за минуты на 185). Профилактика: ограничить ротацию в AdGuardHome.yaml (querylog.interval / rotation) или отключить запись. Отключение (проверено 14.08.2026 на 185): grep -n -A5 "^querylog:" → менять enabled: true → false ТОЛЬКО по номеру строки (sed -i 'Ns/enabled: true/enabled: false/'), потому что enabled: true в конфиге встречается многократно и по тексту не заменить → systemctl restart AdGuardHome. Запись лога на резолвинг не влияет — отключение безопасно. Актуально для ВСЕХ хостов флота — AGH стоит везде (путь лога — data/querylog.json рядом с конфигом, см. секцию про путь конфига).
  2. /var/cache/apt (apt clean, часто 300-400M), /root/.cache, старые ядра (только с --purge, свериться с uname -r).
- Когда du по каталогам не находит едока — искать крупные файлы напрямую (с timeout на стороне хоста): find / -xdev -type f -size +50M -printf "%s %p\n" 2>/dev/null | sort -rn | head -15
- systemctl --failed: snap-*.mount failed — безобидный мусор snapd, не трогать. НЕ игнорировать: unbound и другие DNS-сервисы.
- apt-get --simulate upgrade 2>/dev/null | grep -c "^Inst" → 0 = всё обновлено.
- Ядра: dpkg --list | grep -E "linux-image|linux-headers" — если одно (текущее), чистить нечего.

### unbound падает: root.key 0 байт (проверено 11.08.2026)

Симптом: systemctl status unbound → Active: failed (exit-code), journalctl:
    error: failed to read /var/lib/unbound/root.key
    error: validator: error in trustanchors config
    fatal error: failed to setup modules
systemd сдаётся после 5 рестартов («Start request repeated too quickly»).
Причина: /var/lib/unbound/root.key существует, но размер 0 (занулён обрывом записи/перезагрузкой) — unbound читает пустой auto-trust-anchor и падает.
Диагностика: ls -la /var/lib/unbound/root.key → размер 0.
Фикс (стандартный, безопасный):
    unbound-anchor -a /var/lib/unbound/root.key && systemctl restart unbound
ВАЖНО: AGH продолжает резолвить без unbound (свои upstream) — DNS клиентов жив, авария «тихая», видна только по failed units. Не делать вывод «DNS сломан» без фактической проверки nslookup.

### AdGuardHome: путь конфига не всегда /etc

AGH может запускаться с -w /opt/AdGuardHome (см. ExecStart в юните) — конфиг /opt/AdGuardHome/AdGuardHome.yaml, а не /etc/AdGuardHome/. Путь определять: systemctl cat AdGuardHome | grep -E "ExecStart|WorkingDirectory". Проверка upstream: grep -iE "upstream|bootstrap" <путь>/AdGuardHome.yaml. Живость DNS: nslookup google.com 127.0.0.1 (AGH слушает *:53).

## Открытый DNS-резолвер / DNS-амплификация (проверено 14.08.2026 на 185)

AGH на *:53 при iptables INPUT policy ACCEPT = открытый резолвер → распределённый DNS-флуд:
симптомы — querylog.json растёт до гигабайтов (2.16G на 185), AGH стабильно 25-30% CPU,
сотни уникальных внешних IP с 20+ запросов/сек каждый. Диагностика (tcpdump, подсчёт
уникальных src, In/Out), конфиг-усилители (upstream_mode: parallel — каждый запрос
форвардится ВСЕМ апстримам, ×4 на 185: unbound + 3 DoH) и лечение (iptables ACCEPT только
docker-сети + localhost, DROP остальное; отключение querylog) — references/dns-open-resolver.md.
ПЕРЕД закрытием 53 спросить пользователя о легитимных внешних клиентах по белому IP (ask-first).
ИТОГ 14.08.2026 (финальная схема, 3 слоя, IP-независимая): whitelist по IP отклонён (домашний IP провайдера динамический — смена адреса ломает DNS); применены:
1) nftables dynamic set — динамический бан спамеров: >15 запросов/сек с IP → в бан-сет на 1 час (таймаут продлевается, пока спамит); chain input ОБЯЗАТЕЛЬНО priority -1 (с priority 0 iptables обрабатывает раньше, глобальный лимит съедает поток, и бан-сет не наполняется — проверено: 0 банов при priority filter, 152 IP за минуту при -1); готовый конфиг — templates/dns-flood-protect.nft;
2) iptables hashlimit per-source 15/сек burst 50;
3) iptables глобальный limit 50/сек burst 100 (урезан с 200/сек 14.08.2026; эффект: CPU AGH 28.6% → 3.5%, до AGH ~50/сек вместо ~1600/сек).
Развёрнуто на всех AGH-нодах флота (185, babayka, eurodir, parafin) 14.08.2026.
Команды, синтаксис (nft 1.0.2: после burst обязательно «packets» — без него syntax error), баги
(iptables-nft 1.8.7: recent --update/--rcheck с --seconds/--hitcount → «RULE_INSERT failed (Invalid argument)» —
dynamic ban через recent на nft-бэкенде НЕ работает, использовать nftables) и замеры — references/dns-flood-protection.md.

## Диагностика «VPS недоступен с домашнего IP»

Когда SSH-таймаут / ping 100% loss с дома, но хост активен в панели — НЕ чинить сервер вслепую.
Полный порядок проверок (пробой с датацентра, egress WSL, tcpdump, MTR, CGNAT, перехват DNS) —
references/vps-unreachable-diagnosis.md. Ключевое:
- Сначала проверить хост С ДАТАЦЕНТРА (другой VPS флота): работает с DC, не работает с дома = путь/хостера, не сервер.
- WSL/Windows могут ходить через туннель (egress = IP другого VPS) — все «домашние» тесты невалидны без
  проверки `curl --noproxy '*' https://api.ipify.org`.
- Порт режется даже с DC = анти-DDoS хостера на конкретный порт → сменить порт сервиса.
- Обрыв в MTR внутри сети провайдера (10.64.x/10.16.x) = фильтр оператора до конкретных AS, чинится тикетом.
- HOSTKEY/VDSka хостинг молчит на ПЕРВЫЙ SYN (TCP-защита) — проверка `echo > /dev/tcp/IP/22` даёт ложный CLOSED.
  Проверять баннером: `timeout 8 bash -c 'exec 3<>/dev/tcp/IP/22; head -1 <&3'` → строка "SSH-2.0-OpenSSH..." = порт жив.
- Блокировка «дом ↔ VPS» бывает СИММЕТРИЧНОЙ: дом не достаёт VPS, VPS не достаёт дом (проверять с VPS:
  ping/mtr на домашний IP). Симметрия = маршрутизация/фильтр на стыке AS, НЕ fail2ban/файрвол на сервере.

## Секреты при инвентаризации (токены ботов, API-ключи)

На хостах флота встречаются messenger-агенты (openclaw/hermes/qwen-боты) и
credentials-файлы (OPENCLAW_CREDENTIALS.md и т.п.). Правила:

- Токены/ключи НЕ выводить в контекст LLM. Показывать только имена ключей:
  `grep -oE "^[A-Za-z_0-9]+" FILE | sort -u`
- Маскировать значения в JSON:
  `jq -r '.. | objects | to_entries[] | select(.key|test("token|api_key|secret";"i")) | .key + " = " + (if (.value|type)=="string" then .value[0:6]+"..."+.value[-4:] else (.value|tostring) end)'`
- Перенос секретов между сервисами — сервер-сайд (jq/grep → .env на хосте),
  в контексте — только имена переменных. Токен, засветившийся в переписке,
  считается скомпрометированным (revoke в BotFather).
- Живость токена проверять без вывода значения:
  `TOKEN=$(jq -r ...); curl -s "https://api.telegram.org/bot${TOKEN}/getMe" | jq -c "{ok, bot: .result.username}"`
- API-ключ DeepSeek у Hermes на VPS: /root/.hermes/.env (DEEPSEEK_API_KEY); auth.json хранит ТОЛЬКО fingerprint (source=env:DEEPSEEK_API_KEY, поля secret нет). Смена ключа (проверено 10.08.2026 на 45.134.15.185):
  `sed -i 's|^DEEPSEEK_API_KEY=.*|DEEPSEEK_API_KEY=<NEW>|' /root/.hermes/.env && systemctl restart hermes-gateway`
  Проверка без вывода ключа: `set -a; . /root/.hermes/.env; set +a; curl -s -o /dev/null -w "%{http_code}\n" https://api.deepseek.com/v1/models -H "Authorization: Bearer $DEEPSEEK_API_KEY"` → 200 = ключ жив; `hermes auth status deepseek` → logged in.

## Pitfalls

- AmneziaWG-модуль ставится из исходников (/root/amneziawg-linux-kernel-module-*), НЕ через DKMS → после обновления ядра awg0 не поднимается: `ip link add awg0 type amneziawg` → "Unknown device type", lsmod пуст. Починка: `cd <src> && make && make install && depmod -a && modprobe amneziawg && systemctl start awg-quick@awg0`. При конфликте timer_delete (Ubuntu 5.15.0-187+, backport в ядро): `sed -i 's/static inline int timer_delete(struct/static inline int awg_timer_delete(struct/' compat/compat.h` + `sed -i 's/timer_delete(&/awg_timer_delete(\&/g' *.c`, затем сборка. Проверено 11.08.2026 на vdska. Рекомендация: ставить модуль через DKMS (в исходниках amneziawg-dkms.spec), иначе пересобирать вручную при каждом ядре.
- dpkg warning «/lib/modules/<ver> not empty so not removed» после purge — проверить ls /lib/modules: если осталась только текущая версия, warning игнорировать.
- Ядра удалять только с --purge (иначе остаются конфиги). То же для autoremove.
- Перед удалением ядра всегда сверяться с uname -r; удаление текущего ядра ломает загрузку.
- after apt upgrade не перезагружать без проверки /var/run/reboot-required.
- snap list / любые snap-команды НЕ запускать при диске 100%: snapd виснет на сокете (state activating, snapd.seeded failed), команда не возвращается и вешает ssh-сессию (прецедент 14.08.2026 на 185). Если висит — kill по PID (ps aux | grep snap). snap-*.mount failed — мусор, не трогать, но и не диагностировать через snap.
- Клиентский таймаут ssh НЕ убивает команду на хосте: bash/du/snap остаются висеть и жрать IO. После таймаута — зайти заново, найти и kill по PID.
- НИКОГДА pkill -f по sshd-паттернам («sshd: root@», «bash -c»): под паттерн попадает ТВОЯ собственная сессия — оборвёшь сам себя (прецедент 14.08.2026: pkill -9 -f "sshd: root@" убил текущий заход, вся чистка не выполнилась). Только точечный kill <PID>.
- Тяжёлые du (-sh /usr/*, /opt/*) на полном диске могут висеть минутами — оборачивать timeout N на стороне хоста (`timeout 25 du -sh /opt/*`) или идти через find по крупным файлам (см. health-check).
- После reboot VPS с ранее переполненным диском sshd может подниматься 3+ минут (fsck при загрузке). Симптом «connection refused» на /dev/tcp при живом ping (0% loss) — это загрузка, а не авария: ждать и периодически проверять баннер (`timeout 8 bash -c 'exec 3<>/dev/tcp/IP/22; head -1 <&3'`), не паниковать и не «чинить» сервер (проверено 14.08.2026 на 185: подъём ~3.5 мин).
- tcpdump -i any выводит префикс In/Out перед IP (формат «In IP src...», суффикс интерфейса в конце) — awk-парсинг по $3 ломается (в топ вылезают «In»/«Out»/«eth0» вместо адресов). Для подсчёта источников/частоты — только -i eth0 (конкретный интерфейс) + split($3,a,".") по 4 октета (прецедент 14.08.2026: два сломанных прогона на 185).
