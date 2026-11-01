# OpenClaw Anywhere

Run **OpenClaw** on any Linux box (cloud sandbox, VPS, Nebula, E2B…) and open it from **any phone browser** — no Tailscale app, no port forwarding, fixed HTTPS URL.

What you get (all on one fixed hostname `https://<host>.<tailnet>.ts.net`):

| URL | What | Login |
|---|---|---|
| `https://HOST/` | OpenClaw Control UI (gateway port 18789) | OpenClaw gateway token + device approval |
| `https://HOST:10000/` | Web terminal (ttyd, port 7681) | `WEB_USER` / `WEB_PASS` |
| `https://HOST:8443/vnc.html` | Browser desktop (noVNC, port 6080), optional | first 8 chars of `WEB_PASS` |

How: **Tailscale Funnel** publishes local ports on the public internet with a real HTTPS cert. Nothing listens on a public IP.

> ⚠️ Funnel = public internet. Anyone with the URL reaches the login page. Use strong passwords. Turn off with `scripts/stop.sh`.

---

## Quick start (copy-paste, in order)

### 0. Requirements
- Linux x86_64 or arm64, `bash`, `curl`, `sudo`.
- A free Tailscale account (https://login.tailscale.com).
- An LLM API key for OpenClaw (any OpenAI-compatible provider).

### 1. Get the repo and config
```bash
git clone https://github.com/<you>/openclaw-anywhere.git
cd openclaw-anywhere
cp .env.example .env
nano .env        # set PREFIX, TS_HOSTNAME, WEB_PASS (strong!)
```
`PREFIX` must be a folder that **survives restarts** (e.g. `/workspace` on cloud sandboxes, `$HOME` on a VPS).

### 2. Install
```bash
bash scripts/install.sh
```

### 3. Set up OpenClaw once (interactive)
```bash
export PATH=$PREFIX/opt/node24/bin:$PATH OPENCLAW_STATE_DIR=$PREFIX/openclaw-state
openclaw onboard
```
Pick your model provider, paste the API key, keep gateway on **loopback, port 18789, token auth**. Note the gateway token (or get it later with `openclaw dashboard`).

### 4. Start everything
```bash
bash scripts/start.sh
```
- **First run only:** `tailscale up` prints a login link → open it, approve the machine, run `start.sh` again. (Or put a `TS_AUTHKEY` in `.env` to skip this.)
- If you see **"Funnel is not enabled"** with a link → open it, click enable, run `start.sh` again.
- At the end it prints the 3 URLs.

### 5. Check
```bash
bash scripts/check.sh
```
Wait ~30 s on the very first start (HTTPS cert is being issued). `000` right after start is normal; retry.

### 6. Open OpenClaw on your phone
1. Open `OPENCLAW_URL`, paste the gateway token, connect.
2. It says *pairing required* → on the box run:
   ```bash
   openclaw devices list
   openclaw devices approve <request-id>
   ```
3. Reload the page. Done.

### Stop / restart
```bash
bash scripts/stop.sh     # everything off, Funnel off
bash scripts/start.sh    # back on, same URLs
```
After a sandbox recycle/reboot: just run `start.sh` again. Login, certs and Funnel config are kept in `$PREFIX/tailscale-state`, so the URLs don't change.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Public URL gives `000`, tailscaled log says `no TailscaleVarRoot` | tailscaled must run with `--statedir=...` (start.sh does this). Stop tailscaled and run start.sh. |
| `/dev/net/tun` missing | start.sh auto-uses `--tun=userspace-networking`. Funnel still works. |
| `sudo: unable to resolve host` | Harmless warning, ignore. |
| Funnel URL `000` from inside some sandboxes on 8443/10000 | Outbound non-443 ports may be blocked *from that sandbox*; test from your phone instead. |
| OpenClaw page `pairing required` | Step 6.2 — approve the device. |
| Gateway not starting | `tail -50 /tmp/oc-gw.log`. Usually missing API key → rerun `openclaw onboard`. |
| Box has supervisord (e.g. Nebula) | Restart the gateway with `supervisorctl restart <program>`, not `openclaw gateway restart`. |
| Two `openclaw` binaries | Use the one in `$PREFIX/opt/node24/bin`. Check with `which -a openclaw`. |

Logs: `/tmp/oc-gw.log`, `/tmp/ttyd.log`, `/tmp/tailscaled.log`, `/tmp/keepalive.log`.

## Files
- `scripts/install.sh` – installs Node 24, OpenClaw, Tailscale, ttyd, desktop
- `scripts/start.sh` – starts everything + Funnel, prints URLs (safe to re-run)
- `scripts/keepalive.sh` – restarts anything that dies (started by start.sh)
- `scripts/check.sh` – health check
- `scripts/stop.sh` – stops everything and turns Funnel off
- `AGENTS.md` – exact rules for an AI agent doing this setup
