#!/usr/bin/env bash
# Watchdog: every 60s, re-runs start.sh if anything died. Singleton via flock.
cd "$(dirname "$0")/.."; [ -f .env ] && { set -a; . ./.env; set +a; }
exec 9>"/tmp/openclaw-keepalive.lock"; flock -n 9 || exit 0
while true; do
  down=0
  pgrep -f openclaw-gateway >/dev/null || down=1
  pgrep -x ttyd >/dev/null || down=1
  pgrep -x tailscaled >/dev/null || down=1
  [ "${ENABLE_DESKTOP:-1}" = 1 ] && command -v Xvfb >/dev/null && { pgrep -x websockify >/dev/null || down=1; }
  [ $down = 1 ] && { echo "$(date '+%F %T') restart" >> /tmp/keepalive.log; bash scripts/start.sh >> /tmp/keepalive.log 2>&1; }
  sleep 60
done
