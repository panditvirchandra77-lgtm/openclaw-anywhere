#!/usr/bin/env bash
# Stops everything. Uses exact PIDs (never `pkill -f`, which can kill the shell running it).
PREFIX="${PREFIX:-/workspace}"
sudo "$PREFIX/opt/tailscale/tailscale" --socket=/tmp/tailscaled.sock funnel reset 2>/dev/null
for name in keepalive.sh openclaw-gateway; do for p in $(pgrep -f "$name"); do [ "$p" != "$$" ] && kill "$p" 2>/dev/null; done; done
for name in ttyd websockify x11vnc firefox-esr fluxbox Xvfb; do for p in $(pgrep -x "$name"); do kill "$p" 2>/dev/null; done; done
for p in $(pgrep -x tailscaled); do sudo kill "$p"; done
echo stopped
