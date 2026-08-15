# cua-driver Setup (Windows → WSL)

cua-driver — Rust-бинарник для компьютерного управления (клики, скриншоты, клавиатура). Управляет Windows-десктопом, подключается к Hermes в WSL как MCP-сервер через `mcp_servers` в config.yaml.

## Установка на Windows

**На Windows (PowerShell 7+, от имени администратора):**

```powershell
irm https://raw.githubusercontent.com/trycua/cua/main/libs/cua-driver/scripts/install.ps1 | iex
```

Если GitHub raw заблокирован — сначала включить VPN/AmneziaProxy:

```powershell
$env:http_proxy="http://127.0.0.1:10809"
$env:https_proxy="http://127.0.0.1:10809"
irm https://raw.githubusercontent.com/trycua/cua/main/libs/cua-driver/scripts/install.ps1 | iex
```

## Запуск

```powershell
cua-driver autostart kick    # запустить сейчас (зарегистрирован в автозапуске)
cua-driver serve             # явный запуск сервера (для проверки)
cua-driver status            # статус
cua-driver --version         # cua-driver 0.7.0+
```

## Подключение к Hermes (из WSL)

Установщик выдаёт YAML-конфиг для `~/.hermes/config.yaml`:

```bash
powershell.exe -Command "& 'C:\Users\dkolchin\AppData\Local\Programs\Cua\cua-driver\bin\cua-driver.exe' mcp-config --client hermes"
```

Вывод:
```yaml
mcp_servers:
  cua-driver:
    command: "C:\Users\dkolchin\AppData\Local\Programs\Cua\cua-driver\bin\cua-driver.exe"
    args: ["mcp"]
```

Добавить в `~/.hermes/config.yaml` под `mcp_servers:` с WSL-совместимым путём:

```yaml
  cua-driver:
    command: /mnt/c/Users/dkolchin/AppData/Local/Programs/Cua/cua-driver/bin/cua-driver.exe
    args: ["mcp"]
    enabled: true
```

После добавления — `/reload-mcp` в Hermes, или `/new`.

## Пути

| Компонент | Путь |
|-----------|------|
| Бинарник (Windows) | `C:\Users\dkolchin\AppData\Local\Programs\Cua\cua-driver\bin\cua-driver.exe` |
| Бинарник (из WSL) | `/mnt/c/Users/dkolchin/AppData/Local/Programs/Cua/cua-driver/bin/cua-driver.exe` |
| Пакеты | `C:\Users\dkolchin\.cua-driver\packages\` |
| Текущая версия | `C:\Users\dkolchin\.cua-driver\packages\current\cua-driver.exe` (junction) |

## Проверка из WSL

```bash
/mnt/c/Users/dkolchin/AppData/Local/Programs/Cua/cua-driver/bin/cua-driver.exe --version
# → cua-driver 0.7.0
```

Процесс на Windows после запуска:

```bash
powershell.exe -Command "Get-Process cua-driver -ErrorAction SilentlyContinue | Format-Table Id,ProcessName,StartTime"
```

## Особенности

- cua-driver работает как MCP-сервер через stdio — не HTTP, не REST API. Hermes в WSL запускает `cua-driver.exe mcp` как подпроцесс.
- Для работы нужен запущенный `cua-driver serve` на Windows. `autostart` регистрирует автозапуск при логине.
- `cua-driver` не нужно устанавливать в WSL — Windows-версия доступна через `/mnt/c/` и запускается из WSL напрямую.
- Версия 0.7.0 (на июль 2026).
