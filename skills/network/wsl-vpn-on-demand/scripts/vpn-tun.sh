#!/bin/bash
# Управление sing-box VLESS+Reality туннелем в WSL (on-demand, БЕЗ автозапуска)
# Использование:
#   vpn-tun.sh up    — запустить туннель (прокси на 127.0.0.1:1080)
#   vpn-tun.sh down  — остановить туннель
#   vpn-tun.sh status— статус
# Прокси-переменные НЕ прописываются глобально — source vpn-env.sh на время сессии.

CONFIG=/etc/sing-box/config.json
LOG=/var/log/sing-box.log
PIDFILE=/var/run/sing-box.pid

case "${1:-status}" in
  up)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat $PIDFILE)" 2>/dev/null; then
      echo "туннель уже запущен (pid $(cat $PIDFILE))"
    else
      nohup /usr/local/bin/sing-box run -c "$CONFIG" > "$LOG" 2>&1 &
      echo $! > "$PIDFILE"
      sleep 2
      if kill -0 "$(cat $PIDFILE)" 2>/dev/null; then
        echo "туннель запущен (pid $(cat $PIDFILE)), прокси 127.0.0.1:1080"
        echo "экспорт прокси: source /usr/local/bin/vpn-env.sh"
      else
        echo "ОШИБКА: sing-box не стартовал, смотри $LOG"
        tail -5 "$LOG"
        rm -f "$PIDFILE"
        exit 1
      fi
    fi
    ;;
  down)
    if [ -f "$PIDFILE" ]; then
      kill "$(cat $PIDFILE)" 2>/dev/null
      rm -f "$PIDFILE"
      echo "туннель остановлен"
    else
      pkill -f "sing-box run" 2>/dev/null && echo "туннель остановлен" || echo "туннель не запущен"
    fi
    ;;
  status)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat $PIDFILE)" 2>/dev/null; then
      echo "туннель работает (pid $(cat $PIDFILE))"
      curl -s -m 5 -x http://127.0.0.1:1080 https://ipinfo.io/json 2>/dev/null | head -4
    else
      echo "туннель не запущен"
    fi
    ;;
  *)
    echo "usage: $0 {up|down|status}"
    ;;
esac
