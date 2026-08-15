# Открытый DNS-резолвер / DNS-амплификация (проверено 14.08.2026 на 45.134.15.185)

Сценарий: AGH слушает *:53, iptables INPUT policy ACCEPT (или без правил на 53) —
хост становится открытым DNS-резолвером и ловится ботами/сканерами на амплификацию.

## Симптомы
- querylog.json раздувается до гигабайтов (на 185: 2.16G) — каждый мусорный запрос пишется в лог
- AGH стабильно жрёт CPU 25-30% (ps: `ps -p <pid> -o pid,%cpu,%mem,rss,etime`)
- journalctl -u AdGuardHome: «Consumed 9min+ CPU time» за короткое время работы
- Собственный IP в топе исходящих на 53 (форварды апстримам), десятки-сотни внешних IP
  с частотой 20+/сек с каждого

## Диагностика (команды, порядок)

1. Кто слушает 53 и файрвол:
   ss -ulnp | grep ":53 "; iptables -L INPUT -n | head -15
   (нет DROP/ACCEPT-правил на 53 при policy ACCEPT = открыто наружу)

2. Топ источников (ВАЖНО: -i eth0, не -i any — на any формат строки с префиксом In/Out,
   awk по $3 ломается):
   timeout 15 tcpdump -nn -l -i eth0 "udp port 53" | awk '{split($3,a,"."); print a[1]"."a[2]"."a[3]"."a[4]}' | sort | uniq -c | sort -rn | head -20

3. Сколько уникальных внешних источников (283 за 15 сек на 185 = ботнет-флуд):
   timeout 15 tcpdump -nn -l -i eth0 "udp port 53 and not src host <HOST_IP> and not src host 127.0.0.1" | awk '{split($3,a,"."); print a[1]"."a[2]"."a[3]"."a[4]}' | sort -u | wc -l

4. In/Out за 10 сек (легитимный трафик: In << Out; при флуде In в 2+ раза больше):
   timeout 10 tcpdump -nn -l -i eth0 "udp port 53" | awk '{split($3,a,"."); src=a[1]"."a[2]"."a[3]"."a[4]; if (src=="<HOST_IP>") out++; else inc++} END {print "IN:", inc; print "OUT:", out}'

5. Конфиг AGH (усилители):
   - upstream_mode: parallel — КАЖДЫЙ запрос форвардится всем апстримам (на 185: unbound 127.0.0.1:5353 + 3 DoH = ×4 множитель исходящего)
   - ratelimit: 20 (запросов/сек на /24) — смягчает, но каждый пакет всё равно парсится, CPU горит
   - refuse_any: true — уже защищает от ANY-амплификации (проверить)
   Путь конфига: /opt/AdGuardHome/AdGuardHome.yaml (не /etc!) — определять через systemctl cat AdGuardHome | grep ExecStart

6. Легитимные клиенты — обычно docker-сети, не внешние IP:
   docker network ls + docker network inspect <name> --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}'
   На 185: amnezia-dns-net 172.29.172.0/24 (клиенты AmneziaWG), bridge 172.17.0.0/16, localhost.
   Внешних легитимных клиентов по белому IP, как правило, нет — все внешние IP с 20+/сек это флуд.

## Лечение

1. Отключить querylog (останавливает рост лога, НЕ убирает нагрузку):
   sed -i '105s/enabled: true/enabled: false/' <путь>/AdGuardHome.yaml  (номер строки проверить grep -n -A5 "^querylog:")
   systemctl restart AdGuardHome

2. Удалить существующий лог (иначе висит на диске; после отключения не пересоздаётся):
   systemctl stop AdGuardHome; rm -f <путь>/data/querylog.json; systemctl start AdGuardHome
   Проверка: ls <путь>/data/querylog.json → NO_FILE, systemctl is-active AdGuardHome → active

3. Rate-limit (рекомендуемое лечение; решает и нагрузку, и рост лога при возврате записи):
   iptables -I INPUT 1 -p udp --dport 53 -m hashlimit --hashlimit-above 15/sec --hashlimit-burst 50 --hashlimit-mode srcip --hashlimit-name dns_flood -j DROP
   iptables -A INPUT -p udp --dport 53 -m limit --limit 200/sec --limit-burst 400 -j ACCEPT
   iptables -A INPUT -p udp --dport 53 -j DROP
   (для tcp 53 — аналогичный hashlimit, если нужен)
   netfilter-persistent save
   Почему rate-limit, а НЕ whitelist по IP: домашний IP пользователя ДИНАМИЧЕСКИЙ (провайдер меняет) —
   whitelist по конкретному адресу сломает домашний DNS при смене IP (роутер попадёт в DROP до ручной правки).
   Rate-limit per-source к IP не привязан: легитимный роутер (~1 запрос/15 сек) в 200+ раз ниже порога
   15/сек и не режется никогда, ботнет (20+ /сек с IP) режется ядром. Проверено 14.08.2026 на 185.
   ВАЖНО: per-source hashlimit НЕ режет распределённый флуд суммарно (каждый IP остаётся в рамках лимита) —
   обязателен глобальный `-m limit` (200/сек burst 400) вторым каскадом.
   Whitelist (ACCEPT для docker-сетей + DROP остального) — только если у пользователя есть ФИКСИРОВАННЫЕ
   легитимные внешние клиенты по белому IP; ask-first до выбора схемы.

4. Проверка результата — СЧЁТЧИКИ iptables, не tcpdump: tcpdump захватывает пакеты ДО netfilter
   (дропнутые тоже видны в захвате) — эффективность мерить `iptables -L INPUT -n -v | grep "dpt:53"`
   (растут pkts у DROP/ACCEPT). CPU мерить МГНОВЕННО: `top -b -n 2 -d 2 -p <pid>` (ps %cpu = среднее
   за всё время жизни процесса, на длинном аптайме не отражает текущее). Эффект на 185: до AGH
   ~180 запросов/сек вместо ~1400 (DROP ~1100/сек), CPU 28.6%→12-13%, load 0.50→0.31; домашний DNS
   работает (тест с домашнего IP — RESPONSE_OK).
