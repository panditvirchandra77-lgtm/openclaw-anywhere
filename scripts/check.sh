#!/usr/bin/env bash
# Health check. Expected: gateway 200, ttyd 401 (login wall = good), novnc 200.
code(){ curl -s -m 15 -o /dev/null -w "%{http_code}" "$1"; }
echo "local gateway  : $(code http://127.0.0.1:18789/)   (want 200)"
echo "local ttyd     : $(code http://127.0.0.1:7681/)    (want 401)"
echo "local novnc    : $(code http://127.0.0.1:6080/vnc.html) (want 200, if desktop on)"
H=$(sudo ${PREFIX:-/workspace}/opt/tailscale/tailscale --socket=/tmp/tailscaled.sock status --json 2>/dev/null | grep -o '"DNSName": *"[^"]*' | head -1 | sed 's/.*"//; s/\.$//')
[ -n "$H" ] && { echo "public gateway : $(code https://$H/)"; echo "public ttyd    : $(code https://$H:10000/)"; echo "public novnc   : $(code https://$H:8443/vnc.html)"; }
echo "000 = not reachable. Wait 30s after first Funnel start (cert being issued) and retry."
