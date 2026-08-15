# Защита открытого DNS-резолвера от амплификации (AGH на VPS)

Прецедент: 45.134.15.185, 14.08.2026. Симптом: диск 100%, виновник
/opt/AdGuardHome/data/querylog.json 2.16G; AGH 28.6% CPU постоянно;
iptables INPUT policy ACCEPT при AGH на *:53 = открытый резолвер.

## Диагностика (порядок)

1. iptables -L INPUT -n — policy ACCEPT + AGH на *:53 = открытый резолвер.
2. Замер входящего флуда:
   timeout 10 tcpdump -nn -l -i eth0 "udp port 53 and not src host <IP_VPS>" | wc -l
   — 1000+ пакетов/сек при сотнях уникальных источников = амплификация.
   ВАЖНО: tcpdump на интерфейсе видит пакеты ДО iptables — дропнутые тоже
   считаются. Реальную доставку до приложения мерить счётчиками
   iptables -L INPUT -n -v / nft list chain, не tcpdump.
3. Уникальные источники (парсинг tcpdump):
   ... | awk '{split($3,a,"."); print a[1]"."a[2]"."a[3]"."a[4]}' | sort -u | wc -l
4. upstream_mode: parallel в конфиге AGH = каждый запрос шлётся N апстримам
   (множитель исходящего трафика; в пр. — 4x: unbound + 3 DoH).
5. Мгновенный CPU процесса: top -b -n 2 -d 2 -p <pid> (ps %cpu — СРЕДНЕЕ
   за время жизни процесса, мгновенную нагрузку не показывает).

## Защита (3 слоя, IP-независимо)

Подходит при динамическом IP клиента (домашний роутер): лимиты привязаны
к ЧАСТОТЕ, а не к адресу — смена IP ничего не ломает. Whitelist по IP
в этом случае недопустим.

### Слой 1 — nftables dynamic set (динамический бан спамеров)

/etc/nftables.conf:
```
table inet dns_protect {
	chain input {
		type filter hook input priority -1; policy accept;
		udp dport 53 add @flood { ip saddr limit rate over 15/second burst 50 packets } drop
		udp dport 53 ip saddr @flood drop
	}
	set flood {
		type ipv4_addr
		flags dynamic, timeout
		timeout 1h
	}
}
```
- Применение: nft -f /etc/nftables.conf; systemctl enable --now nftables
  (сервис переживает перезагрузку).
- КРИТИЧНО: chain input обязан быть priority -1 (не filter/0). С priority 0
  iptables (тоже 0) обрабатывает пакеты раньше, глобальный лимит съедает
  поток, и бан-сет не наполняется (проверено 14.08.2026: priority filter —
  сет пуст; priority -1 — 152 IP забанены за минуту).
- Синтаксис nft 1.0.2: после burst обязательно слово «packets», иначе
  «syntax error, unexpected '}', expecting packets».
- Семантика: источник, превысивший 15 запросов/сек (burst 50) на UDP 53,
  добавляется в set flood на 1 час; таймаут продлевается, пока спамит;
  перестал — бан снимается сам. Легитимный клиент (1 запрос/15 сек) в 200+
  раз ниже порога.
- Проверка: nft list set inet dns_protect flood | grep -c expires

### Слой 2 — iptables per-source hashlimit (второй эшелон, до бана)
iptables -I INPUT 1 -p udp --dport 53 -m hashlimit --hashlimit-above 15/sec \
  --hashlimit-burst 50 --hashlimit-mode srcip --hashlimit-name dns_flood -j DROP
iptables -I INPUT 2 -p udp --dport 53 -j ACCEPT

### Слой 3 — iptables глобальный лимит (предохранитель от суммарного флуда)
ФИНАЛЬНЫЙ (урезан 14.08.2026 по просьбе пользователя: 200 → 50/сек):
iptables -A INPUT -p udp --dport 53 -m limit --limit 50/sec --limit-burst 100 -j ACCEPT
iptables -A INPUT -p udp --dport 53 -j DROP
Порядок правил ОБЯЗАТЕЛЕН: hashlimit DROP → limit ACCEPT → финальный DROP.
Эффект на 185: CPU AGH 28.6% → 3.5%, до AGH ~50/сек вместо ~1600/сек (в 32 раза меньше).
Легитимный роутер (1-10/сек steady-state) в 5-50 раз ниже лимита; burst 100 покрывает
пики (холодный кэш, массовые обновления). Симптом «упёрся в лимит» — медленный резолвинг.

Сохранение: netfilter-persistent save (iptables) + nftables.service (nft).

## Баги и грабли

- iptables-nft 1.8.7 (Ubuntu 22.04): recent --update/--rcheck с --seconds/
  --hitcount → «RULE_INSERT failed (Invalid argument)». Динамический бан
  через recent на nft-бэкенде НЕ работает — использовать nftables dynamic set.
- Двойное применение конфига (nft -f вручную + systemctl enable --now nftables)
  даёт дубликаты правил в chain. Применять один раз; при дубликате:
  nft flush table inet dns_protect; nft -f /etc/nftables.conf.
- Отключение querylog (enabled: false) НЕ удаляет существующий файл; AGH
  пересоздаёт querylog.json при рестарте, если лог ещё включён. Удалять
  файл на остановленном сервисе: systemctl stop AdGuardHome; rm -f ...; start.
- Размер querylog.json на открытом резолвере растёт мгновенно (2.16G) —
  это симптом амплификации, а не первопричина; лечить резолвер, а не лог.
- Замена правила iptables через -D + -A ломает ПОРЯДОК: новый ACCEPT встаёт
  В КОНЕЦ цепочки, ПОСЛЕ финального DROP → ACCEPT никогда не матчится
  (счётчик 0), весь UDP 53 дропается (прецедент 14.08.2026: дважды). При
  изменении лимита: удалить финальный DROP, добавить ACCEPT, добавить DROP.
- В /etc/nftables.conf НЕ должно быть «flush ruleset» (дефолт Ubuntu): при
  старте nftables.service он снесёт ВСЕ nft-таблицы, включая созданные
  iptables-nft (f2b-sshd и пр.). Заменять файл целиком на конфиг без flush.
- scp на хосты флота триггерит security scan (raw IP) и может быть
  заблокирован без подтверждения. Доставка конфига без scp — с хоста, где
  файл уже есть: cat /etc/nftables.conf | sshpass ssh root@<ip> "cat > /etc/nftables.conf.new"
- Развёртывание на N хостов: iptables-правила добавлять -A (в конец) —
  существующие правила (f2b-sshd, ACCEPT udp 54711 на eurodir и т.п.) не
  трогаются. На хостах без флуда бан-сет пуст (CPU 0%) — защита стоит про запас.

## Тест после настройки

- Легитимный клиент (домашний IP): python3 UDP-запрос к <IP>:53 → RESPONSE_OK.
- python3 socket надёжнее dig/nslookup (dnsutils может отсутствовать на хосте).
- С чужого VPS (не спамящего): при лимитах (не тотальном DROP) ответ будет —
  проверять именно спам-паттерн, а не «молчит ли чужой IP».
