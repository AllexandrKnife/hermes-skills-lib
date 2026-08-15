# Cudy WR3000S — детали прошивки со стока (кейс 08.2026)

## Образы
- Официальный OpenWrt 25.12.5 (mediatek/filogic):
  - squashfs-sysupgrade.bin — SHA256 b0a26c80fa458b4b743508a6a6de8aa9d19867fa3deb1c3c49e40194d61aa8b2
  - initramfs-kernel.bin — SHA256 d47d301062086f51186f79f0f8f4cf7bff5b666f22f5a0a16cac9e5447780060
- Промежуточный Cudy: cudy_wr3000s-v1-sysupgrade_20251119.bin
  - MD5 403e276f74fd29917fd4260294d1a137, размер 14 945 872 байт
  - Источник: Google Drive «Cudy Intermediary OpenWRT Firmware» (folder id 1BKVarlwlNxf7uJUtRhuMGUqeCa5KpMnj)
  - Файл: «WR3000S 1.0.zip» (file id 1cUhLp9TasSvEOBUnS8RG4y2ApM8yniRe), внутри cudy_wr3000s-v1-sysupgrade_20251119.bin
  - Скачивание папки: python3 -m gdown --folder <folder_url> --json (список); по id: gdown <file_id> -O out.zip
  - ВАЖНО: это общая папка с кучей чужих файлов (формы EAEU-загрузок) — качать только нужный id

## Структура образов (проверено xxd/strings)
- Cudy-образ: заголовок `0100 64aa 7856 3412 ...` (Cudy-magic — сток проверяет его на шаге upload);
  внутри FIT-образы (magic d00dfeed на смещениях ~605177, 2099200, 2365600);
  OpenWrt-метаданные в ХВОСТЕ (metadata_version 1.1, dist "SNAPSHOT-CUDY", revision r23001+886-38c150612c),
  длина метаданных — последние 4 байта LE (у нас 0x124 = 292)
- Официальный: начинается текстом `sysupgrade-cudy_wr3000s-v1/...`;
  метаданные в хвосте: {"metadata_version":"1.1","compat_version":"1.0","supported_devices":["cudy,wr3000s-v1","R59"],...},
  длина 0x114 = 276. Оба образа имеют ВАЛИДНЫЕ метаданные — отказ «Image metadata not present» это проблема модуля стока, не образов

## Логин в сток (sysauth.js, /luci-static/light/js/sysauth.js)
- Форма: _csrf, token, salt, zonename, timeclock, luci_username (hidden=admin), luci_password
- JS на submit: zonename=timezone, timeclock=unix; если salt есть: luci_password = sha256(sha256(pwd+salt)+token)
- Практика: браузер (browser_console: установить #luci_password2, form.requestSubmit()) работает;
  curl-клоны ловят 403 (антибот/бан по IP) — не тратить время на ретраи, чинить заголовки бессмысленно

## Апгрейд-модуль Cudy /cgi-bin/luci/admin/system/upgrade
- upload_file() из cbi.js: FormData { "<id>.upload"="true", "<id>"=file } → POST action формы (без token!)
- Ответ: «The flash image was uploaded. Below is the checksum... Click Proceed» + MD5 + кнопка name="cbid.upgrade.1.proceed"
- Proceed: token + timeclock + cbi.submit=1 + cbid.upgrade.1.proceed=Proceed → flash
- Отказ в syslog (System Log → /cgi-bin/luci/admin/system/status/syslog): `upgrade: Image metadata not present`
- После неудачной попытки роутер может перезагрузиться и вернуться на сток (проверять: uptime на Status, ETag индекса)

## Сток-ограничения
- SSH 22 refused, telnet 23 closed
- /admin/system/flash, /admin/system/flashops → 404 «No page is registered»
- Аптайм/статус: System Status; системный лог: /cgi-bin/luci/admin/system/status/syslog (загружается cbi_xhr_load)
- Пароль Wi-Fi стока (из flash-страницы) — отдельный от пароля админки (у нас админка 1qsxdrgb, Wi-Fi 31122009)

## Серийники
- S/N с 2543+ = новая флеш-память (ESMT), нужны образы >= 24.10.5 (предупреждение с форума OpenWrt, ноябрь 2025)
- У нас S0007084261208266 EAEU 1.0 = старая память (GigaDevice) — любые образы подходят
- EAEU/RU-прошивки строже к апгрейду, чем глобальные (причина отказа «metadata not present»)

## Промежуточный OpenWrt 23.05-SNAPSHOT-CUDY
- kernel 5.15.158, LuCI openwrt-23.05 branch git-24.148; SSH root/пароль РАБОТАЕТ (в отличие от стока)
- LAN по умолчанию 192.168.1.1 → сразу менять на 192.168.10.1 (uci network.lan.ipaddr) из-за конфликта с Keenetic
- WiFi по умолчанию disabled — включить: uci set wireless.radio0/1.disabled='0', ssid/encryption psk2/key

## Финальный OpenWrt 25.12.5
- scp образа в /tmp + `sysupgrade /tmp/openwrt-25.12.5-...-squashfs-sysupgrade.bin` (БЕЗ -n — сохраняет LAN-IP и пароль)
- Проверка после ребута: ssh + cat /etc/openwrt_release → DISTRIB_RELEASE='25.12.5'
- Настройка WAN (PPPoE): uci set network.wan.proto='pppoe'; username; password; uci commit; /etc/init.d/network restart; ifstatus wan

## Таймлайн граблей (что НЕ работает)
1. Прямой POST с файлом+token+cbi.submit=1 (без шага .upload): «Waiting for changes... device disconnected» + перезагрузка → сток (флеш не применился)
2. upload (правильный) + Proceed: «System - Rebooting...» → сток, в syslog «Image metadata not present»
3. Стандартный flashops: 404 (выпилен производителем)
4. У пользователя ВРУЧНУЮ через веб-интерфейс (Advanced Settings → Firmware → файл → Продолжить) промежуточный образ применился — если API-путь не идёт, отдать пользователю руки

## WISP-наблюдения
- Сканирование 5 ГГц с AP-радио: iw dev phy1-ap0 scan (iwinfo phy1 scan молчит)
- Keenetic-0180 виден и в 2.4, и в 5 ГГц с ОДИНАКОВЫМ именем (без -5G суффикса)
- Вокруг много чужих Keenetic-XXXX — искать именно свой SSID, не первый попавшийся
