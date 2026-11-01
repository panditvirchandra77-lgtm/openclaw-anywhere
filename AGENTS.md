# Instructions for AI agents

Follow these steps exactly. Do not improvise.

1. `cp .env.example .env`. Ask the human for `WEB_PASS` and `TS_HOSTNAME` (or `TS_AUTHKEY`). Never invent or print passwords/tokens.
2. Run `bash scripts/install.sh`. If it fails, show the last 20 lines of output to the human and stop.
3. `openclaw onboard` is interactive: let the human do it, or ask them for the provider + API key. Keep gateway bind = loopback, port = 18789.
4. Run `bash scripts/start.sh`.
   - If output contains a `https://login.tailscale.com/...` link → give it to the human, wait for "done", run start.sh again.
   - If output contains "Funnel is not enabled" + link → same: give link, wait, re-run.
5. Run `bash scripts/check.sh`. Success = local gateway 200, local ttyd 401. Public `000` in the first minute: wait 30 s, retry up to 3 times.
6. Give the human the URLs printed by start.sh. Tell them Funnel is public.
7. When they report "pairing required": `openclaw devices list`, then `openclaw devices approve <id>` for the newest pending request.

## Hard rules
- NEVER use `pkill -f` (it can kill your own shell). Use `scripts/stop.sh` or `kill <exact pid>`.
- Back up a config before editing: `cp file file.bak.$(date +%Y%m%d%H%M%S)`.
- Never commit `.env`. Never paste tokens or passwords into chat or logs.
- Don't reinstall if it's already installed: re-running start.sh is the fix for "it's down".
- Always check HTTP status codes with `curl -s -o /dev/null -w "%{http_code}"` instead of guessing.
- Run long commands with a timeout; if something loops twice, stop and report.
