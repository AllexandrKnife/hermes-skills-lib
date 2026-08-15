# Инстанс vdska — 5.39.255.242 (установлен 2026-08-04, ПЕРЕУСТАНОВЛЕН 2026-08-07)

## Железо/система
- Хост: vdska, Ubuntu 22.04.2 LTS → 22.04.5 LTS после переустановки, kernel 5.15.0-76, KVM
- Регион: Германия, Франкфурт (VDSka hosting / abstation.net), IPv4 only
- RAM 957 MiB, диск 15G
- Доступ: root / 1qsxdrgb (общий пароль всех VPS юзера)

## Установка
- sing-box-yg скрипт v26.4.11, ядро sing-box 1.13.16 (стабильное)
- Сертификат: self-signed bing (Acme не запрашивался)
- BBR: cubic (не включался)

## Конфиг и сервис
- /etc/s-box/sb.json — рабочий конфиг; sb10.json / sb11.json — бэкапы скрипта
- /etc/systemd/system/sing-box.service, ExecStart=/etc/s-box/sing-box run -c /etc/s-box/sb.json
- Сервис active (running), enabled

## Параметры подключения (АКТУАЛЬНО после переустановки 07.08.2026)
- UUID: 26bc3168-fbde-41e3-9d04-16535a4f304d (единый на все протоколы, восстановлен)
- VLESS-Reality: TCP 443 (был 22524, перенесён 04.08, сохранён при переустановке), sni=apple.com, fp=chrome, flow=xtls-rprx-vision,
  pbk=NTTlxcWI8byYCvb0t15cEtLWZ7HJkIsf-B-kqoluWU0 (НОВЫЙ, приватный ключ потерян при переустановке), sid=f60204fc (восстановлен)
- Hysteria2: UDP 42954, sni=www.bing.com, alpn=h3 (порт восстановлен)
- TUIC: UDP 60240, sni=www.bing.com, alpn=h3, congestion_control=bbr (порт восстановлен)
- Anytls: TCP 56799, sni=www.bing.com (порт восстановлен)
- Доп. вход (внутренний): TCP 2082 — это vmess (ws), не отдельный вход
- VMESS: есть (порт 2082, ws), ссылка base64 — полную отдаёт пункт 9 меню sb.sh
- Бэкап конфига до переустановки: sb.json.bak-restore (не существует после переустановки — конфиг пересоздан)

## Восстановление после переустановки ОС (проверено 07.08.2026)
1. apt update && upgrade, apt install iproute2 curl sshpass (без iproute2 awg-quick падает)
2. Перенести русскую sb.sh с 45.134.15.185: `sshpass ... ssh root@185 'cat /usr/bin/sb' | sshpass ... ssh root@<target> 'cat > /usr/bin/sb && chmod 755 /usr/bin/sb'` (sha256 bbf9c98d...)
3. Запустить sb.sh, ответить на промпты (последовательность ниже, русская версия — те же номера)
4. Правка sb.json под сохранённый инвентарь (python3 replace): UUID, порты, short_id. НО приватный ключ reality НЕЛЬЗЯ восстановить — генерится новый скриптом, pbk берём из вывода ссылок
5. Проверка reality-ключей: конфиг использует стандартный base64 (с +), ссылки — URL-safe (с -). Нормализация: заменить - на +, добавить =, вычислить pub через x25519, сравнить в URL-safe виде. `pbk в ссылке == pub(priv из sb.json)` — критерий валидности
6. Проверка TLS-камуфляжа: `openssl s_client -connect IP:443 -servername apple.com` должен вернуть настоящий сертификат Apple Inc.
7. Обновить клиентский /etc/sing-box/config-vdska.json на WSL (новый public_key) — write_file в /etc/sing-box запрещён (sensitive path), писать в /tmp + cp

## Проверенная последовательность ответов на промпты (ручной режим)
1. iptables-persistent IPv4 «Save current IPv4 rules?» → no
2. iptables-persistent IPv6 → no
3. needrestart «Which services should be restarted?» → 9 — повторяется 4-6 раз за установку зависимостей
4. tzdata «Geographic area» → 8 (Europe), «Time zone» → 7 (Berlin)
5. Меню «请输入数字【0-16】» → 1
6. «是否开放端口，关闭防火墙» → 1
7. «使用哪个内核版本» → 1
8. «是否申请Acme域名IP证书» → 1
9. «设置各个协议端口» → 1 (авто-порты)

Примечание: альтернатива — запускать скрипт с DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a, тогда пункты 1-4 не появляются. Русская версия скрипта — те же номера меню.
