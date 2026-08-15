---
name: sing-box-server-setup
version: 1.0.0
description: "Use when Поставить/обновить sing-box на VPS (sb.sh"
critic_status: done
---

# Sing-box server setup (yonggekkk sb.sh)

## Когда использовать
- Юзер просит установить sing-box / прокси-сервер на свой VPS
- Обновить ядро или пересобрать конфиг существующего sing-box
- Скрипт: https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh

## Точка возврата перед обновлением (предв. действие)
Перед обновлением ядра/пересборкой конфига на РАБОЧЕМ инстансе:
`cp /etc/s-box/sb.json /etc/s-box/sb.json.bak.$(date +%s)` + фиксация версии
(`sing-box version`, sha256 /usr/bin/sb). Скрипт делает свои бэкапы (sb10/sb11) при
установке, но ручное обновление их не гарантирует. Откат конфига — минута,
восстановление приватного ключа reality из головы — невозможно (теряется при
переустановке, см. «Восстановление после переустановки ОС»).

## Быстрый путь (без debconf/needrestart-промптов)
sshpass -p '<pass>' ssh -t root@<IP> 'DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)'
Env-переменные глушат apt-промпты (iptables-persistent, tzdata, needrestart). Остаются только меню самого скрипта.

## Проверенный путь (PTY + ручные ответы)
1. Запуск в фоне с PTY:
   terminal(background=true, pty=true):
   sshpass -p '<pass>' ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@<IP> 'bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)'
2. Драйв через process(action=submit) в порядке появления:
   - iptables-persistent «Save current IPv4 rules?» → no; затем IPv6 → no
   - tzdata «Geographic area» → 8 (Europe), «Time zone» → 7 (Berlin)
   - needrestart «Which services should be restarted?» → 9 (none) — ВСПЛЫВАЕТ МНОГОКРАТНО за установку зависимостей, отвечать каждый раз
3. Меню скрипта (появляется после доустановки зависимостей):
   - «请输入数字【0-16】» → 1 (install)
   - «是否开放端口，关闭防火墙» → 1 (открыть порты, снять firewall — дефолт)
   - «使用哪个内核版本» → 1 (последний стабильный)
   - «是否申请Acme域名IP证书» → 1 (self-signed, дефолт; для Reality/камуфляжа достаточно)
   - «设置各个协议端口» → 1 (авто-случайные порты 10000-65535)
4. После генерации скрипт печатает share-ссылки всех протоколов и ВЫХОДИТ (SSH-сессия закрывается — это норма, не ошибка).

## Замена версии скрипта (китайская sb.sh → русская)
Скрипт yg при установке само-копируется в /usr/bin/sb (китайская версия ~149 КБ).
ВАЖНО (проверено 07.08.2026): замена на русскую версию нужна ПОСЛЕ установки, а не до —
инсталлятор при установке перезаписывает /usr/bin/sb своей (китайской) копией.
Признак китайской копии: sha256 67aacb52dd09c1ed97fe379ef0823322babe02c887833b718d499d6a772622ff,
размер 149572 байт, grep «请输入» даёт >0, русских строк 0.
Русская версия скрипта живёт на 45.134.15.185:/usr/bin/sb (156 КБ, sha256 bbf9c98d3e1f9d96ed3c127b54014d9680969bfb903a6a94c3388a0a306e687e).

Процедура:
1. Бэкап текущей: cp /usr/bin/sb /usr/bin/sb.bak.cn
2. Перенос VPS→VPS напрямую (без промежуточного файла на WSL):
   sshpass -p '<pass>' ssh root@45.134.15.185 'cat /usr/bin/sb' | sshpass -p '<pass>' ssh root@<target> 'cat > /usr/bin/sb && chmod 755 /usr/bin/sb'
3. Проверка: sha256sum /usr/bin/sb (должен совпасть с источником), bash -n /usr/bin/sb (синтаксис), grep русских строк меню («Установка необходимых зависимостей…»)
4. Русская версия: те же номера пунктов меню — все ответы из раздела «Проверенный путь» валидны без изменений
Откат: mv /usr/bin/sb.bak.cn /usr/bin/sb

## Верификация
systemctl is-active sing-box
systemctl status sing-box --no-pager | head -8
grep -o '"listen_port":[0-9]*' /etc/s-box/sb.json          # все порты (вкл. UDP)
cat /etc/systemd/system/sing-box.service | grep ExecStart  # путь к конфигу
# живые TCP-порты без ss/netstat:
awk 'NR>1 {split($2,a,":"); port=strtonum("0x"a[2]); if (port>1000 && $4=="0A") print port}' /proc/net/tcp /proc/net/tcp6 | sort -n | uniq

## Что получаем
- Сервис: sing-box.service (enabled), конфиг: /etc/s-box/sb.json (+ sb10/sb11.json — бэкапы)
- Протоколы: VLESS-Reality (TCP), Hysteria2 (UDP/QUIC), TUIC (UDP/QUIC), Anytls (TCP), доп. вход на ~2082
- UUID единый на все протоколы; сертификаты self-signed в /etc/s-box/cert

## Pitfalls
- `apt-get autoremove -y --purge` при чистке VPS может снести iproute2 на минимальных образах Ubuntu → `wg-quick`/`ip` падают «ip: command not found». Фикс: `apt-get install -y iproute2`.
- Пользователь прерывает длинные интерактивные пробы («стоп») — короткие проверки с таймаутами. При денае прямого действия (блокировка сети) — ожидает запуск через qwen-task.sh.
- ss/netstat часто не установлены на минимальных VPS — юзать /proc/net/tcp или grep по конфигу
- hy2/tuic слушают UDP/QUIC — в /proc/net/tcp их НЕ видно, это не ошибка; проверять grep по /etc/s-box/sb.json
- needrestart-промпт повторяется несколько раз за установку — не пугаться, отвечать 9
- vmess-ссылка в захваченном выводе может обрезаться (base64) — полные ссылки даёт пункт 9 меню скрипта
- Автопорты 10000-65535; если VPS за фаерволом хостера — открыть порты в панели
- Меню скрипта на китайском — отвечать по номерам, не по тексту
- «Заменить версию скрипта» = заменить /usr/bin/sb (самоустановленная копия), а не /root/sb.sh — файла sb.sh в /root нет
- Поиск скрипта на другом VPS: find / -name "sb.sh" не находит — искать /usr/bin/sb и /root/sbyg_update
- Если юзер пишет «статус» посреди установки — этапы идут в порядке: зависимости → ядро → сертификат → порты → ссылки; дать краткую сводку и продолжить

## Восстановление после переустановки ОС (кейс vdska 08.2026)

При переустановке приватный ключ reality (x25519) ТЕРЯЕТСЯ — он был только в sb.json.
UUID, порты, sni, short_id — НЕ ключи, возвращаются 1-в-1 из references/sing-box-yg-instance.md.

Порядок:
1. Установить sing-box заново (русскую sb.sh — ПОСЛЕ установки, см. выше).
2. Правка sb.json: вернуть сохранённые UUID/порты/short_id/sni (python replace + json.loads + sing-box check).
3. Приватный ключ reality оставить новый; новый pbk взять из выведенных ссылок или вычислить из private_key (ниже).
4. Обновить клиентские конфиги (WSL /etc/sing-box/config-*.json → public_key), ссылки клиентам.
5. Проверка камуфляжа:
   echo | openssl s_client -connect <ip>:443 -servername apple.com 2>/dev/null | openssl x509 -noout -subject
   → настоящий сертификат Apple = сниффер видит apple.com, а не прокси.

## Верификация пары ключей reality (priv → pub)

Проверить, что private_key в sb.json соответствует pbk из ссылок (python3 + cryptography):

```python
import base64
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey
from cryptography.hazmat.primitives import serialization
k = '<private_key из sb.json>'
raw = k.replace('-', '+').replace('_', '/') + '='   # URL-safe -> std base64
priv = base64.b64decode(raw)
pub = X25519PrivateKey.from_private_bytes(priv).public_key().public_bytes(
    serialization.Encoding.Raw, serialization.PublicFormat.Raw)
derived = base64.b64encode(pub).decode().rstrip('=').replace('+', '-').replace('/', '_')
print(derived)   # сравнить с pbk= из ссылки (URL-safe, без паддинга)
```

Питфолл: sb.json хранит ключ в стандартном base64 (+), ссылки — в URL-safe (-). Сравнивать
только после нормализации обеих сторон — иначе валидная пара выглядит «несовпадающей».

## Ссылки
- references/sing-box-yg-instance.md — инстанс vdska 5.39.255.242: UUID, порты, ключи, проверенная последовательность промптов
- references/vps-reinstall-recovery.md — план восстановления ноды после переустановки ОС (кейс vdska 08.2026): что сохраняется/теряется, порядок работ, выбор ОС, диагностика SSH
