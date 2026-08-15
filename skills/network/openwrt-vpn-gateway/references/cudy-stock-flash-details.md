# Cudy WR3000S сток 2.4.6 RU → OpenWrt: детали рабочего флеша (08.2026)

Сессия: роутер куплен (S/N S0007084261208266, EAEU 1.0 — старая флеш-
память, подходит любой образ). Сток: FW 2.4.6-20250527-170229 RU.

## Доступ к стоку (LuCI-обёртка Cudy)

- GET / → 200, index редиректит на /cgi-bin/luci/ (LuCI 25.x, git-25.147).
- Логин-форма: hidden `_csrf`, `token`, `salt`, `luci_username=admin`,
  видимое поле `#luci_password2`. sysauth.js на submit:
  `luci_password = sha256(sha256(pwd + salt) + token)`.
  username НЕ root — hidden-поле `luci_username` = "admin".
- Веб-пароль ≠ пароль WiFi. У пользователя: WiFi-пароль 31122009
  (показывается на экране перепрошивки), пароль админки 1qsxdrgb.
- После нескольких неудачных логинов с одного IP GET /cgi-bin/luci/ →
  403 (страница логина всё ещё в теле, но сессия не выдаётся). Лечится
  временем или сменой источника (браузер с другого IP работает).
- PowerShell: Find-NetRoute / Get-NetIPConfiguration — для диагностики
  маршрутизации при двух роутерах.

## Прошивочный модуль стока

- Кастомный `/cgi-bin/luci/admin/system/upgrade` (НЕ стандартный flashops).
  Стандартные `/admin/system/flash`, `/flashops` — 404 (удалены).
- Двухшаговый flow (JS `upload_file` из /luci-static/light/js/cbi.js):
  1. AJAX FormData: `cbid.upgrade.1.firmware.upload=true` +
     `cbid.upgrade.1.firmware=<file>` → ответ: страница подтверждения с
     MD5/размером файла и кнопкой Proceed (`cbid.upgrade.1.proceed`).
  2. POST: token + timeclock + cbi.submit=1 + cbid.upgrade.1.proceed →
     прошивка + reboot.
- Проверка формата на загрузке: официальный OpenWrt sysupgrade →
  «File is invalid. Please retry.» (нет Cudy-магии 0100 64aa... в начале;
  у официального образа заголовок `sysupgrade-cudy_wr3000s-v1/...`).
- Cudy-промежуточный (подписанный) проходит загрузку, MD5 совпадает.
  Scripted-шаг Proceed (fetch из консоли браузера) → в системном логе
  (`/admin/system/status/syslog`, грузится через cbi_xhr_load)
  появляется `upgrade: Image metadata not present` (uhttpd), роутер
  перезагружается и откатывается на сток.
- **Ручная заливка пользователем в браузере РАБОТАЕТ.** Вероятная
  причина отличия — чувствительность модуля к токенам/полям между шагами
  (token в шаге Proceed должен быть свежим из страницы подтверждения).
  Практический вывод: скриптовать не пытаться долго — отдать шаг
  пользователю (файл на рабочий стол, инструкция из 5 пунктов).

## Образы

- Официальный: openwrt.org/releases/25.12.5/targets/mediatek/filogic/
  cudy_wr3000s-v1-{initramfs-kernel,squashfs-sysupgrade}.bin (SHA256
  проверены; sysupgrade b0a26c80...). Метаданные в хвосте образа:
  `{"metadata_version":"1.1","supported_devices":["cudy,wr3000s-v1","R59"]...}`,
  длина поля в последних 4 байтах (0x114 = 276).
- Cudy-промежуточный: общий Google Drive «Cudy Intermediary OpenWRT
  Firmware» (id 1BKVarlwlNxf7uJUtRhuMGUqeCa5KpMnj) → «WR3000S 1.0.zip» →
  cudy_wr3000s-v1-sysupgrade_20251119.bin (MD5 403e276f..., 14.9 МБ).
  Свой контейнер: заголовок 0100 64aa 7856 3412..., внутри FIT (d00dfeed
  на смещениях ~605К/2099К/2365К), метаданные в хвосте тоже есть
  (metadata_version 1.1, dist SNAPSHOT-CUDY).

## Рабочая последовательность

1. Сток → (веб, руками) Cudy-промежуточный → OpenWrt 23.05-SNAPSHOT-CUDY
   (LuCI, kernel 5.15.158, LAN 192.168.1.1, Wi-Fi выключен).
2. LAN сразу на 192.168.10.1 (иначе конфликт с Keenetic 192.168.1.1).
3. SSH root (задать пароль) → scp официального sysupgrade →
   `sysupgrade /tmp/openwrt-25.12.5-...-squashfs-sysupgrade.bin` (без -n).
   Миграция 23.05→25.12.5 с keep settings: LAN-IP и root-пароль
   сохраняются, роутер поднимается за ~30 сек.
4. WAN PPPoE (uci network.wan proto/username/password), wifi reload для
   включения радио (SSID/пароль, psk2).
