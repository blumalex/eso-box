# eso-box

**Carry your Claude Code sessions across all your devices.** An always-on machine at home (the "box") runs your
Claude Code sessions. Your laptop opens them over SSH, your phone through the Claude app, and you
can switch between them mid-conversation: start on the laptop, carry on from the phone, finish on
the laptop.

eso-box is a small set of scripts and settings on top of tmux, Tailscale and Claude Code's own
features. It is not affiliated with Anthropic.

## Features

- **Your real setup.** Claude works with your data, secrets, running dev servers and signed-in
  tools.
- **The same live session, on any device.** Pick it up from any laptop over SSH (bash, zsh or
  PowerShell, on Windows, macOS or Linux), or from your phone in the Claude app.
- **Start on your phone, finish at your desk.** Start new sessions on the box from the Claude
  app, then continue them in a terminal: `/resume` lists them as `☏ · <the phone's title>`.
- **It keeps going.** Close every device and the work continues.
- **A box that looks after itself.** It never sleeps (lid closed is fine), reboots itself after a
  freeze, comes back after a power cut, and reconnects to your phone after network outages.
  (Linux; macOS untested.)
- **Tabs that tell you what's happening.** Each session keeps Claude's title for it on every
  device, a phone-started one keeps the phone's title in a terminal, and names you set with
  `/rename` stick. Its tab shows ◐ while Claude works, ✳ when it's done or waiting on you, and
  💤 once it has been done for 5 minutes, so you can tell what just finished.
- **Check on the box from anywhere.** An optional health page shows uptime, temperatures, CPU,
  memory, disk, battery, pending updates, a needed restart and Claude's sessions, with up to 30
  days of history. An optional healthchecks.io ping keeps its last status readable, and alerts
  you, when the box goes down. (Linux.)
- **Try your app on your phone.** Open it against the box's dev server.
- **Private by default.** Every device reaches the box over Tailscale, with no ports open on
  your router. With `--firewall`, a Linux box accepts connections only from your devices.
- **Nothing new to trust.** It's just tmux, Tailscale and Claude Code's own Remote Control, and
  every script is short enough to read.

## How it works

```
  Windows / macOS / Linux laptop ──ssh (Tailscale)──┐
                                                    ▼
                         box (Linux or macOS):  tmux ─▶ claude ◀── Remote Control ── Claude app (iOS, Android)
                                                                                     or claude.ai/code (any browser)
```

The session never moves. It runs on the box inside tmux with Claude Code's
[Remote Control](https://code.claude.com/docs/en/remote-control) on. The laptop attaches to the
tmux session, and the phone attaches through Remote Control. Both see and drive the same Claude.

## How is this different from `claude --cloud`?

**Cloud sessions work on a copy of your project, on Anthropic's machines. eso-box lets you work on your project from anywhere, on your own machine.**

A [cloud session](https://code.claude.com/docs/en/claude-code-on-the-web) (`claude --cloud`, or
claude.ai/code) runs on a fresh Anthropic VM with a clean clone of your GitHub repo. eso-box runs
your sessions on your own machine, in your real setup.

| | Cloud session | eso-box |
|---|---|---|
| Your setup | A fresh clone, rebuilt by a setup script: no untracked files, local `.env` files, databases or signed-in tools | Already there |
| Moving to a terminal | `--teleport` makes a copy that doesn't sync back | The same live session, both ways |
| Dev servers and long jobs | An idle session's VM pauses after a few minutes and can be reclaimed, along with anything running | Keep running |
| Your app on your phone | No way to reach the VM | Open the box's dev server |
| Networks | Public sites you allow; not your LAN, VPN or tailnet | Anything the box can reach |
| Hardware | About 4 vCPUs, 16 GB of RAM, no GPU | Yours |
| Your code | Copied to Anthropic's VM; GitHub access through the Claude GitHub App or your `gh` token | Stays on your disk; only what Claude reads or runs goes to Anthropic |
| Isolation | A separate VM per task, with credentials kept outside it | None: Claude works with your own logins and access |
| Upkeep | None | A machine you keep on and secure |

Use cloud sessions for self-contained tasks and for running many at once, and the box for the
project you work in every day. They combine: run `claude --cloud` from the box to hand off a side
task.

Anthropic's docs point here too: *"To run Claude Code on your own always-on machine and drive it
from other devices, use Remote Control"*
([self-hosted environments](https://code.claude.com/docs/en/self-hosted-environments)), and for
work beyond the cloud VM's limits, *"use Remote Control to run Claude Code on your own hardware"*
([cloud environments](https://code.claude.com/docs/en/cloud-environments#resource-limits)).

## What's in it

| Path | What it does |
|---|---|
| `box/linux/setup-root.sh` | System settings for running unattended: never sleep, ignore the lid, reboot by itself after a crash or freeze, skip the boot menu wait after a power cut, battery charge limit on laptops, optional tailnet-only firewall |
| `box/macos/setup-root.sh` | The same for a Mac (Mac mini). **Untested** |
| `install.sh` | Installs the tools, tab titles and hooks, and runs Claude Code's Remote Control server as a service so sessions started from the phone run on the box |
| `bin/eso-session` | What `box` runs on the box: opens or creates a tmux session running Claude |
| `bin/eso-rc-loop` | Keeps the Remote Control server running (it exits after ~10 min without network) |
| `bin/eso-rc-title` | Hook: the phone's session list shows Claude's own title for each session |
| `bin/eso-phone` | Lists sessions started from the phone, with the `/resume` line that continues one in a terminal |
| `bin/eso-phone-sync` | Hook: `/resume` lists sessions started from the phone, named `☏ · <the phone's title>` |
| `bin/eso-tab-stop` | Hook: the tab turns `✳` when Claude's turn ends, unless background agents are still running |
| `bin/eso-update-check` | Hook and `boxls`: says when a newer eso-box is out; never installs anything |
| `bin/eso-health`, `config/health.html` | The optional health page (`install.sh --health`, Linux): a reading a minute, served at `http://<box>:8090` to your tailnet only |
| `config/tmux.conf` | Terminal tab shows `◐ <Claude's title> · <session>` while working, `✳` when done, `💤` 5 min later |
| `client/box.sh`, `client/box.ps1` | `box` and `boxls` for bash/zsh (Linux, macOS, WSL, Termux) and PowerShell |

## Status

- **Linux box: tested** on Ubuntu Desktop 26.04 (a ThinkPad laptop with the lid closed), with
  Claude Code 2.1.32x, for days of daily use, overnight runs, power cuts and reboots. The
  scripts here are generalized from that setup.
- **macOS box: untested.** Written from Apple's documented settings; see
  [docs/gotchas.md](docs/gotchas.md#macos-box) for what to check first. Reports welcome.
- **Windows as the box:** not supported yet (WSL2, Windows sleep, no Tailscale SSH server).
  Windows works fine as a client.
- **Clients:** Windows (WSL bash and PowerShell), Linux, macOS, Android (Claude app; Termux for
  SSH), iPhone and iPad (Claude app; any SSH app).

## What you need

- A Claude subscription that includes Remote Control, signed in with your claude.ai account
  (not an API key).
- A free [Tailscale](https://tailscale.com) account: every device reaches the box over your
  private tailnet, with no ports opened on your router.
- The box: a machine that can stay on. A spare laptop works (the battery rides out short power
  cuts); a Mac mini works if you accept the FileVault tradeoff in [docs/security.md](docs/security.md).

## Set up the box

`install.sh` backs up your Claude settings and tmux config before changing them, adds its hooks
next to yours, and is safe to rerun. Rerunning it is also how you update (see [Update](#update)).

### Linux (Debian/Ubuntu)

1. Install the OS. For a desktop you can use over remote desktop, enable automatic login.
   Read [docs/security.md](docs/security.md) before choosing disk encryption: a passphrase
   prompt blocks unattended boot after a power cut.
2. In the BIOS, turn on "power on with AC attach" (or "restore on AC power loss"), so the box
   boots by itself when power returns.
3. Tailscale: `curl -fsSL https://tailscale.com/install.sh | sh`, then `sudo tailscale up --ssh`.
   In the [admin console](https://login.tailscale.com/admin/machines), open the box's menu and
   **Disable key expiry** (otherwise it drops off the tailnet after 180 days).
4. Claude Code: [install it](https://code.claude.com/docs/en/setup), then run `claude` once in
   your project folder, sign in, and accept the trust question.
5. eso-box:
   ```bash
   git clone https://github.com/blumalex/eso-box ~/eso-box && cd ~/eso-box
   sudo box/linux/setup-root.sh            # add --firewall once you're connected over Tailscale
   ./install.sh --dir ~/code/myproject     # add --health for the health page
   sudo systemctl reboot -i
   ```

### macOS (untested)

1. System Settings > Users & Groups: automatic login (needs FileVault off; see
   [docs/security.md](docs/security.md)).
2. [Homebrew](https://brew.sh), then `brew install tmux jq tailscale`. For Tailscale SSH use this
   open-source `tailscaled` (`sudo brew services start tailscale`, `sudo tailscale up --ssh`); the
   App Store app can't run an SSH server. Or turn on Remote Login and use SSH keys.
3. Claude Code, as in step 4 above.
4. eso-box: clone it, then `sudo box/macos/setup-root.sh` and `./install.sh --dir ~/code/myproject`.

## Set up each device

Install Tailscale on each device and sign in to the same tailnet. Then:

| Device | Terminal | Phone-style |
|---|---|---|
| Windows | PowerShell: add `$env:ESO_BOX_HOST = 'mybox'` and `. "$HOME\eso-box\client\box.ps1"` to `$PROFILE`. Or WSL, as Linux | claude.ai/code in a browser |
| macOS, Linux | Add `export ESO_BOX_HOST=mybox` and `. ~/eso-box/client/box.sh` to `~/.zshrc` or `~/.bashrc` | claude.ai/code in a browser |
| Android | Termux (`pkg install openssh`), then as Linux | Claude app |
| iPhone, iPad | Any SSH app: `ssh mybox -t '~/.local/bin/eso-session 3'` | Claude app |

`mybox` is the box's Tailscale name; use `user@mybox` if your user name there differs. Only
the laptop needs this repo, for the client file. In Claude Code's `/config` on the box, turn on
**Push when actions required** so permission prompts reach your phone.

## Daily use

- `box`: a new Claude session on the box. tmux numbers them 0, 1, 2...
- `box 3`: back into session 3 (or a new one named 3). `boxls` lists them with Claude's titles.
- Close the window to leave a session running; it keeps working with the laptop asleep. Quitting
  Claude (Ctrl+C twice) ends the session.
- Phone: every session on the box appears in the Claude app. Type in either place.
- Sessions started **from the phone** run on the box too. To continue one in a terminal, once:
  let Claude finish its turn, run `box`, type `/resume` and pick its `☏ · <title>` entry.
  From then on use the terminal session's own entry on the phone. See [docs/using.md](docs/using.md).

## Health page (Linux, optional)

`./install.sh --health` runs a small page at `http://<box>:8090`, for any device on your tailnet:

- **Now:** restart needed, pending updates (Debian/Ubuntu), failed services, power (laptops),
  uptime, CPU, temperatures, memory, disk, and Claude Code's sessions and memory.
- **History:** the past 1 hour, 24 hours, 7 days or 30 days of CPU, temperatures, memory and
  battery, from a reading every minute, kept 31 days in `~/.local/share/eso-box/health.db`. A
  break in a line is time the box was off.

It answers only your tailnet and the box itself, with or without `--firewall`. A rerun keeps it
on; `./install.sh --no-health` removes it.

**When the box is down, so is its page.** To still see its last status, and get an alert when it
goes quiet: create a free check at [healthchecks.io](https://healthchecks.io) with a period of
15 minutes and a grace time of 15 minutes, then put the check's ping URL on the box:

```bash
(umask 077; echo 'https://hc-ping.com/<your-check-id>' > ~/.config/eso-box/health-ping-url)
```

Every 15 minutes the box sends that URL a short status text (the "Now" numbers). healthchecks.io
keeps the recent ones, and when a ping is late it emails you, or notifies your phone through one
of its integrations. Any healthchecks-compatible URL works, a self-hosted one included.

## Update

On the box:

```bash
cd ~/eso-box && git pull && ./install.sh --no-service
```

The rerun replaces eso-box's own tab-title block in `~/.tmux.conf` and its own hooks in
`~/.claude/settings.json`, leaves yours alone, and backs up both first (`*.pre-eso-box-upgrade`).
It keeps your settings in `~/.config/eso-box/config`, including the `--dir` folder. A tab-title
block you edited by hand is left as it is. `--no-service` skips restarting the Remote Control
server. Running sessions pick up the new hooks by themselves.

On each laptop, also run `git pull` in `~/eso-box` and open a new terminal: `box` and `boxls`
come from the laptop's own clone.

When an update is out, `boxls` ends with a line saying so, and so does the top of each new
Claude session on the box. eso-box checks GitHub for it once a day and never installs anything
by itself; see [docs/security.md](docs/security.md) for what the check sends, and how to turn
it off.

## Docs

- [docs/using.md](docs/using.md): the flows step by step, and what happens when the network,
  power or the laptop goes away
- [docs/gotchas.md](docs/gotchas.md): what we ran into and how it's handled
- [docs/background-sessions.md](docs/background-sessions.md): Claude Code's own background
  sessions (`claude agents`) as an alternative to tmux
- [docs/security.md](docs/security.md): the tradeoffs, and what to revoke if the box is stolen

## Limitations

- `eso-phone`, `eso-rc-title` and `eso-phone-sync` read Claude Code's transcript files, an
  internal format that can change between versions. If they stop working after an update, the
  rest still works. `eso-phone-sync` also edits them: in each phone session's file it changes the
  one mark that hides it from `/resume` (in place, same length, logged to
  `~/.local/state/eso-phone-sync.log`) and appends a name.
- The phone's title for a phone-started session comes from an internal claude.ai API, as Claude
  Code itself calls it (untested on a Mac box). Without it, that session's terminal tab just says
  "Claude Code".
- tmux sessions don't survive a reboot. The conversations do: `box`, then `claude --continue`
  or `/resume`.
- The Remote Control server serves one project folder. Sessions you start with `box` can `cd`
  anywhere.

## License

MIT
