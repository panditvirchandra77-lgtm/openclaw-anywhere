#!/usr/bin/env bash
# Starts: OpenClaw gateway, ttyd, (desktop), tailscaled, and Tailscale Funnel.
# Idempotent: anything already running is left alone. Prints public URLs at the end.
set -u
cd "$(dirname "$0")/.."; [ -f .env ] && { set -a; . ./.env; set +a; }
PREFIX="${PREFIX:-/workspace}"; OPT="$PREFIX/opt"; BIN="$PREFIX/bin"
: "${WEB_PASS:?set WEB_PASS in .env}"; WEB_USER="${WEB_USER:-admin}"
export PATH="$OPT/node24/bin:$BIN:$PATH" OPENCLAW_STATE_DIR="$PREFIX/openclaw-state" DISPLAY=:1
TS="sudo $OPT/tailscale/tailscale --socket=/tmp/tailscaled.sock"
say(){ echo "[start] $*"; }
up(){ pgrep -x "$1" >/dev/null; }

# OpenClaw gateway (listens 127.0.0.1:18789)
pgrep -f openclaw-gateway >/dev/null || { say gateway; (cd /tmp && setsid openclaw gateway run >/tmp/oc-gw.log 2>&1 </dev/null &); }

# Web terminal
up ttyd || { say ttyd; setsid "$BIN/ttyd" -p 7681 -W -c "$WEB_USER:$WEB_PASS" bash >/tmp/ttyd.log 2>&1 </dev/null & }

# Desktop (Xvfb + fluxbox + firefox + x11vnc + noVNC on 6080)
if [ "${ENABLE_DESKTOP:-1}" = 1 ] && command -v Xvfb >/dev/null; then
  up Xvfb || { setsid Xvfb :1 -screen 0 1280x800x24 >/tmp/xvfb.log 2>&1 </dev/null & sleep 2; }
  up fluxbox || setsid fluxbox >/tmp/fluxbox.log 2>&1 </dev/null &
  up firefox-esr || setsid firefox-esr --no-remote >/tmp/firefox.log 2>&1 </dev/null &
  mkdir -p ~/.vnc; x11vnc -storepasswd "${WEB_PASS:0:8}" ~/.vnc/passwd >/dev/null 2>&1
  up x11vnc || { setsid x11vnc -display :1 -rfbauth ~/.vnc/passwd -forever -shared -rfbport 5900 -localhost >/tmp/x11vnc.log 2>&1 </dev/null & sleep 2; }
  up websockify || setsid websockify --web=/usr/share/novnc 6080 localhost:5900 >/tmp/novnc.log 2>&1 </dev/null &
fi

# Tailscale. --statedir is REQUIRED or Funnel HTTPS fails with "no TailscaleVarRoot".
if ! up tailscaled; then
  say tailscaled
  TUN=""; [ -c /dev/net/tun ] || TUN="--tun=userspace-networking"
  sudo nohup "$OPT/tailscale/tailscaled" $TUN --statedir="$PREFIX/tailscale-state" \
    --state="$PREFIX/tailscale-state/tailscaled.state" --socket=/tmp/tailscaled.sock >/tmp/tailscaled.log 2>&1 &
  sleep 4
fi
AK=""; [ -n "${TS_AUTHKEY:-}" ] && AK="--authkey=$TS_AUTHKEY"
$TS up --hostname="${TS_HOSTNAME:-my-claw}" $AK --timeout=30s 2>&1 | grep -v 'resolve host' || true
# ^ first time without authkey this prints a login URL: open it, approve, re-run start.sh

# Funnel (public HTTPS). Only ports 443, 8443, 10000 are allowed.
$TS funnel --bg 18789                       >/dev/null 2>&1   # OpenClaw  -> https://HOST/
[ "${ENABLE_DESKTOP:-1}" = 1 ] && $TS funnel --bg --https=8443 6080 >/dev/null 2>&1   # desktop -> :8443/vnc.html
$TS funnel --bg --https=10000 7681          >/dev/null 2>&1   # terminal -> :10000
# ^ if it prints "Funnel is not enabled on your tailnet" + a link: open link, enable, re-run.

nohup bash "$(pwd)/scripts/keepalive.sh" >/dev/null 2>&1 &
sleep 3; H=$($TS status --json 2>/dev/null | grep -o '"DNSName": *"[^"]*' | head -1 | sed 's/.*"//; s/\.$//')
echo "OPENCLAW_URL=https://$H/"
[ "${ENABLE_DESKTOP:-1}" = 1 ] && echo "DESKTOP_URL=https://$H:8443/vnc.html"
echo "TERMINAL_URL=https://$H:10000/"
