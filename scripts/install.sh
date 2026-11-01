#!/usr/bin/env bash
# Installs Node 24, OpenClaw, Tailscale, ttyd (and optional desktop) into $PREFIX/opt.
# Safe to re-run: skips anything already installed.
set -euo pipefail
cd "$(dirname "$0")/.."; [ -f .env ] && { set -a; . ./.env; set +a; }
PREFIX="${PREFIX:-/workspace}"; OPT="$PREFIX/opt"; BIN="$PREFIX/bin"
mkdir -p "$OPT" "$BIN" "$PREFIX/openclaw-state" "$PREFIX/tailscale-state"
ARCH=$(uname -m); case "$ARCH" in x86_64) NA=x64; TA=amd64; YA=x86_64;; aarch64) NA=arm64; TA=arm64; YA=aarch64;; *) echo "unsupported arch $ARCH"; exit 1;; esac
say(){ echo "[install] $*"; }

# 1. Node 24 (private copy, not system node)
if [ ! -x "$OPT/node24/bin/node" ]; then
  say "node 24"; V=$(curl -fsSL https://nodejs.org/dist/latest-v24.x/SHASUMS256.txt | grep -o "node-v24[^ ]*-linux-$NA.tar.xz" | head -1)
  curl -fsSL "https://nodejs.org/dist/latest-v24.x/$V" | tar -xJ -C "$OPT"; mv "$OPT/${V%.tar.xz}" "$OPT/node24"
fi
export PATH="$OPT/node24/bin:$PATH"

# 2. OpenClaw
command -v openclaw >/dev/null 2>&1 || { say "openclaw"; npm install -g openclaw@latest; }

# 3. Tailscale (static binaries)
if [ ! -x "$OPT/tailscale/tailscaled" ]; then
  say "tailscale"; T=$(curl -fsSL "https://pkgs.tailscale.com/stable/?mode=json" | grep -o "tailscale_[0-9.]*_$TA.tgz" | head -1)
  curl -fsSL "https://pkgs.tailscale.com/stable/$T" | tar -xz -C "$OPT"; mv "$OPT/${T%.tgz}" "$OPT/tailscale"
fi

# 4. ttyd (web terminal)
[ -x "$BIN/ttyd" ] || { say "ttyd"; curl -fsSL -o "$BIN/ttyd" "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.$YA"; chmod +x "$BIN/ttyd"; }

# 5. Optional desktop (needs apt + sudo)
if [ "${ENABLE_DESKTOP:-1}" = 1 ] && command -v apt-get >/dev/null; then
  for b in Xvfb x11vnc fluxbox websockify firefox-esr; do command -v $b >/dev/null || NEED=1; done
  [ "${NEED:-0}" = 1 ] && { say "desktop pkgs"; sudo apt-get update -qq; sudo apt-get install -y --no-install-recommends xvfb x11vnc fluxbox novnc websockify firefox-esr; }
fi
say "done. Next: run 'openclaw onboard' once (see README step 3)."
