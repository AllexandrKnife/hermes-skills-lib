# Кейс: Cudy WR3000S как домашний VLESS-гейтвей (08.2026)

Контекст: пользователь хотел весь домашний трафик через VLESS+Reality
(сервер vdska 5.39.255.242). Keenetic (KN-1713/5.0.8, MT7621) гонит WG/AWG
только 15-25 Мбит/с (CPU-потолок, замерено ранее). Решение: OpenWrt-роутер
на MT7981.

## Железо (подтверждено boot-логами из wiki OpenWrt)

- CPU: MediaTek MT7981 (1300 МГц), 2 ядра в логе (SMP: 2 processors)
- RAM: 256 MiB DDR3; SPI NAND 128 MiB (GigaDevice/ESMT), mtd: BL2/u-boot-env/
  Factory/bdinfo/FIP/ubi (ubi 64 MiB)
- Порты: wan + lan1-lan4 (MT7531, uplink 2.5G), USB 3.0, aarch64 (arm64)
- OpenWrt wiki: openwrt.org/toh/cudy/wr3000s_v1

## Почему Cudy WR3000S, а не Xiaomi AX3000T (оба MT7981B, DNS 08.2026)

| Критерий | Cudy WR3000S (4 999 ₽) | Xiaomi AX3000T (4 799 ₽) |
|---|---|---|
| ОЗУ | 256 МБ | 128 МБ (впритык) |
| Установка OpenWrt | вендорские сборки, веб-морда (или UART+TFTP) | только разблокировка загрузчика (X-MePatch, 4PDA) |
| Порты | 5×GbE + 2.5G uplink | 4×GbE |

## Процедура прошивки (из wiki, подтверждено)

1. Попытка А: стоковый веб-интерфейс Cudy → System → Firmware Upgrade →
   initramfs-kernel.bin. Не гарантировано (подпись).
2. Попытка Б (wiki): UART (115200 8N1, USB-UART 3.3V) + держать Reset при
   питании → U-Boot shell → TFTP с 192.168.1.88 (файл cudy3000s.bin):
   `tftpboot 0x46000000 cudy3000s.bin; bootm 0x46000000`
3. После загрузки initramfs: scp sysupgrade → `sysupgrade -n`.
4. Прошивка: OpenWrt 25.12.5 mediatek/filogic, образы cudy_wr3000s-v1
   (initramfs-kernel.bin SHA256 d47d3010…, squashfs-sysupgrade.bin
   SHA256 b0a26c80… — проверены по официальному sha256sums).

## Что реально сделано (комплект готов, роутер ещё не куплен)

Рабочий комплект: /root/cudy-wr3000s-kit/
- firmware/ — оба образа 25.12.5 + sha256sums (SHA256 подтверждён)
- sing-box/ — sing-box-1.13.11-linux-arm64.tar.gz (GitHub release)
- config/config.json — tun-конфиг, проверен `sing-box check` (CONFIG OK)
- scripts/install-singbox.sh — установка на роутер одной командой
- scripts/sing-box.init — procd-скрипт
- README.txt — полная инструкция (флеш, PPPoE, DNS, откат, трубли)

## Пойманные грабли

- sing-box 1.13.11: legacy DNS (`"address": "tls://..."`) → FATAL
  ENABLE_DEPRECATED_LEGACY_DNS_SERVERS; фикс — новый формат
  `{"type": "tls", "server": "1.1.1.1", "server_port": 853}`.
- sing-box нет в официальном packages feed OpenWrt 25.12.5 (mediatek_filogic,
  проверено grep по Packages.gz) → бинарником с GitHub.
- Цены/наличие: DNS города (страница каталога, jina-read через туннель);
  Ozon/Avito/mvideo блокируют; pepper.ru — исторические сделки как ориентир.

## Не сделано (следующий шаг)

- Флеш и настройка по прибытии роутера (фаза 2, по README.txt).
- Проверить: принимает ли стоковый веб-интерфейс initramfs (тогда UART не нужен).
- Вписать PPPoE-логин/пароль провайдера (взять из Keenetic show running-config).
