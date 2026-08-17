# Флот VPS пользователя — инвентарь

Дата сбора: 2026-08-06 (SSH-разведка, все хосты отвечали). Креды на всех: root/VPS_ROOT_PASSWORD_PLACEHOLDER. Реестр IP — в памяти агента.

## 45.134.15.185
- Старый основной VPS: sing-box + AdGuardHome (*:53) + unbound; docker AmneziaWG UDP 37487/37409.
- ОС — Ubuntu (проверять /etc/os-release при работе).

## 5.39.255.242 (vdska) — переустановлен 2026-08-07
- ОС: Ubuntu 22.04.5 LTS, ядро 5.15.0-76 (та же версия, что до переустановки).
- sing-box 1.13.16: VLESS+Reality :443 (UUID 26bc3168-fbde-41e3-9d04-16535a4f304d, sid f60204fc, sni apple.com), vmess 2082, hy2 42954, tuic 60240, anytls 56799. Приватный ключ reality НОВЫЙ (после переустановки): pbk=NTTlxcWI8byYCvb0t15cEtLWZ7HJkIsf-B-kqoluWU0 — обновлён в /etc/sing-box/config-vdska.json на WSL.
- AWG v1.0: UDP 50000 (был 51871 — порт блокируется анти-DDoS хостера VDSka даже с датацентров), сеть 10.7.0.0/24, MTU 1420, Jc=5 Jmin=30 Jmax=50 S1=16 S2=16, H1-H4 1234567890/987654321/555555555/111111111, PSK mNANbVQE... (тот же). Серверный ключ НОВЫЙ: pub La988Qb3YGfWDOksrgtAfHP5KO9CKROfvb01qDslpDE=; клиент Keenetic Wireguard6: pub npwRXFJ0aaqllt0cPmUpSBw+U660YlstQbXcMd9vcm4=, addr 10.7.0.2, приоритет 16033, Policy1.
- НЮАНС (не диагностировать заново): UDP с домашнего CGNAT (100.64.x.x) до vdska НЕ доходит — фильтр хостера, конфиги верны. С датацентров (185, eurodir) UDP на 50000 проходит. Keenetic-туннель не поднимется, пока хостера не откроет UDP. Старый порт 51871 заблокирован полностью (даже с 185).
- 14.08.2026: SSH с домашнего IP (TATTELECOM 5.101.22.132) тоже не проходит (таймаут); с DC (185) — OK, баннер есть. fail2ban не при делах (в логе 0 совпадений). AGH на хосте НЕТ (после переустановки не ставился) — querylog отключать нечего.
- WSL-туннель (14.08.2026): sing-box mixed-прокси 127.0.0.1:1080 → 185 (config.json), автозапуск в /etc/wsl.conf [boot] + env proxy в /root/.bashrc (no_proxy: deepseek/github/checko). vdska/parafin с дома обрублены (прямой канал до провайдера закрыт) — только через 185/eurodir. WG на 46 запрещён (WSL к WG не подключается).
- Webmin: установлен 2026-08-07 (https://5.39.255.242:10000, root/VPS_ROOT_PASSWORD_PLACEHOLDER) — запасной доступ к панели.

## 204.77.1.107 (parafin.duckdns.org) — Ubuntu 24.04.3, ядро 6.8.0-136
- Docker: amnezia-wireguard (UDP 33330), amnezia-awg (UDP 43354), amnezia-xray (:443), wg-easy (UDP 51820, веб-панель 51821)
- sing-box (sbyg): VLESS 63102, VMess 2095, Hysteria2 64701, Tuic 53150, AnyTLS 12354
- Отдельные сервисы: hysteria-server, mita (11000-11005), AdGuardHome *:53 и :3000, unbound 127.0.0.1:5353, webmin 10000/20000, glances, fail2ban, hermes-gateway (systemd, Telegram @WG_BBBot, заменил openclaw-gateway 07.08.2026; бэкап конфига OpenClaw — /root/.openclaw.backup-migration); MiMo Code CLI 0.1.10 (клон, конфиг ~/.config/mimocode/mimocode.jsonc, MCP hermes подключён, делегат /root/scripts/mimo-delegate.sh)
- В /root: скрипты анализа атак (attackers_analysis.sh, cleanup_final_report.md), playwright-тесты (test_reuters.js и др.), OPENCLAW_CREDENTIALS.md, установщики hysteria/tuic; qwen-бот @Vott_Bot_Bot НЕ запускается (менеджер qwen-simple-bot-manager.sh удалён, @reboot-cron почищен 07.08.2026, конфиг /root/.qwen/ цел)
- Cron: 01:00 рестарт sing-box (больше нет @reboot qwen-бота — запись удалена 07.08.2026)
- 14.08.2026: SSH с дома не проходит (таймаут), с DC (185) — OK; fail2ban домашний IP не банил. AGH querylog отключён (флотовая чистка 14.08.2026).

## 87.121.38.60 (babayka.duckdns.org) — Ubuntu 22.04.5, ядро 5.15.0-186
- Docker: amnezia-wireguard (UDP 36614), amnezia-xray (:443), amnezia-awg (UDP 30772)
- sing-box (sbyg): VLESS 62832, VMess 8880, Hysteria2 41287, Tuic 43959, AnyTLS 27000
- mita (11000-11005), AdGuardHome *:53 и :3000, unbound (8953/5353), webmin+usermin 10000/20000
- Сервис qwen-channel (бот); в /root: wireguard-install.sh, wireguard-manager.sh, oauth_creds.json, sessions, sb.bak
- Cron: ежедневный ребут 03:50, рестарт sing-box 01:00

## 46.30.47.120 (vm598494.eurodir.ru) — Debian 12 bookworm, ядро 6.1.0-37
- Docker: amnezia-xray (:777), amnezia-awg (UDP 33940), watchtower (автоапдейт образов)
- sing-box (sbyg): VLESS 443, VMess 2086, Hysteria2 28840, Tuic 58919, AnyTLS 48469
- mita (11000-11005), AdGuardHome *:53 и :3000, unbound, webmin 10000
- В /opt: outline (Outline VPN), wg-easy; wg установлен + wg_manager* скрипты
- Cron: ребут 04:30, рестарт sing-box 01:00

## Общее для sbyg-нод
- Конфиг sing-box: /etc/s-box/sb.json; сервис sing-box.service (ExecStart: /etc/s-box/sing-box run -c /etc/s-box/sb.json)
- Стандартный набор inbounds: vless, vmess, hysteria2, tuic, anytls — порты авто-случайные (разные на каждом хосте)
- mita run — демон, присутствует на всех sbyg-нодах (порты 11000-11005); назначение уточнять на хосте (mita help)
- Порт 53 на всех нодах слушает AdGuardHome, unbound — на 127.0.0.1 (5353 или 8953)
- webmin (miniserv.pl) на 10000/20000 — на всех
- На всех: fail2ban, cron рестарта sing-box в 01:00; на части хостов — ночной ребут (03:50/04:30)

## Изменения
- 2026-08-14: на ВСЕХ AGH-нодах (185, babayka, eurodir, parafin) развёрнута защита DNS от флуда (открытый резолвер атаковали амплификацией): nftables dns_protect (dynamic set, бан >15 запросов/сек с IP на 1 час, priority -1; /etc/nftables.conf; шаблон templates/dns-flood-protect.nft) + iptables hashlimit per-source 15/сек + глобальный лимит 50/сек. Бэкапы: /etc/nftables.conf.bak. На 185 флуд был (152 IP в бане, CPU AGH 28.6→3.5%); parafin тоже ловил; babayka/eurodir — без флуда (защита про запас).
- 2026-08-14: 185 — обслуживание: диск был 100% (0 свободно), виновник /opt/AdGuardHome/data/querylog.json 2.16G (удалён, AGH пересоздал; диск 81%, свободно 1.5G). unbound root.key снова 0 байт → восстановлен unbound-anchor (повтор прецедента 11.08.2026). snapd завис на полном диске (snap list висел, state activating). Также на 185: Hermes установлен в /usr/local/lib/hermes-agent (venv + .git ~293M), sing-box в /etc/s-box/. После — флотовая чистка: querylog отключён на 185/babayka/eurodir/parafin (enabled: false, рестарт AGH, все active); vdska/parafin недоступны с домашнего IP TATTELECOM (5.101.22.132) — с DC (185) OK, fail2ban не банил.
- 2026-08-07: vdska переустановлен (Ubuntu 22.04.5), sing-box/AWG/webmin восстановлены; AWG порт 51871→50000 (51871 блокирует анти-DDoS хостера VDSka); reality-ключ и AWG-ключ сервера НОВЫЕ (старые приватные потеряны при переустановке); русификация /usr/bin/sb выполнена ПОСЛЕ установки (инсталлятор затирает русскую копию). WSL-конфиг /etc/sing-box/config-vdska.json обновлён под новый pbk.
- 2026-08-06: добавлены 204.77.1.107, 87.121.38.60, 46.30.47.120 (ранее в памяти их не было).
