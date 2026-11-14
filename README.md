# eso-box

**Carry your Claude Code sessions across all your devices.** An always-on machine at home (the "box") runs your
Claude Code sessions. Your laptop opens them over SSH, your phone through the Claude app, and you
can switch between them mid-conversation: start on the laptop, carry on from the phone, finish on
the laptop.

```
  Windows / macOS / Linux laptop ──ssh (Tailscale)──┐
                                                    ▼
                         box (Linux or macOS):  tmux ─▶ claude ◀── Remote Control ── Claude app (iOS, Android)
                                                                                     or claude.ai/code (any browser)
```

The session never moves. It runs on the box inside tmux with Claude Code's
[Remote Control](https://code.claude.com/docs/en/remote-control) on. The laptop attaches to the
tmux session, and the phone attaches through Remote Control. Both see and drive the same Claude.

eso-box is a small set of scripts and settings on top of tmux, Tailscale and Claude Code's own
features. It is not affiliated with Anthropic.

## Features

- **Carry your Claude Code sessions across all your devices.** Start Claude on your laptop, answer it from your phone in the
  Claude app, finish back at your desk. It's the same live conversation, not a copy.
- **Pick up phone sessions at your desk.** Sessions you start in the Claude app run on the box
  too; `eso-phone` gives you the `/resume` line that continues one in a terminal.
- **SSH from any laptop.** `box` opens a session and `boxls` lists them, in bash or zsh (Linux,
  macOS, WSL, Termux) and PowerShell. Over Tailscale, so no ports open on your router.
- **Titles that follow the session.** Each session is named after Claude's own title for it, the
  same on your terminal tab, in `boxls` and in the Claude app. Names you set with `/rename` stick.
- **See which tab is working.** Each tab shows ◐ while Claude works and ✳ when it's done or
  waiting on you.
- **Keeps working when you leave.** Close the laptop or lose Wi-Fi; the session keeps running on
  the box.
- **Start new sessions from your phone.** An always-on Remote Control server lets the Claude app
  start sessions on the box, in your project folder or each in its own git worktree. It restarts
  itself after network outages.
- **A box that looks after itself.** It never sleeps (lid closed is fine), reboots by itself
  after a freeze or kernel panic, comes back after a power cut, and caps the battery charge on
  laptops that support it. (Linux; the macOS script, untested, sets the Mac equivalents.)
- **Tailnet-only, if you want.** With `--firewall`, a Linux box accepts connections only from
  your own devices.
- **Safe to install.** It backs up your Claude settings and tmux config, adds its hooks next to
  yours, and changes nothing when you run it again.
- **Nothing new to trust.** No app, server or relay of its own: tmux, Tailscale and Claude Code's
  Remote Control do the work, and every script is short enough to read.

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
| `config/tmux.conf` | Terminal tab shows `◐ <Claude's title> · <session>` while working, `✳` when done |
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
   ./install.sh --dir ~/code/myproject
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
  let Claude finish its turn, run `box`, type `! eso-phone`, paste the `/resume <id>` line.
  From then on use the terminal session's own entry on the phone. See [docs/using.md](docs/using.md).

## Docs

- [docs/using.md](docs/using.md): the flows step by step, and what happens when the network,
  power or the laptop goes away
- [docs/gotchas.md](docs/gotchas.md): what we ran into and how it's handled
- [docs/background-sessions.md](docs/background-sessions.md): Claude Code's own background
  sessions (`claude agents`) as an alternative to tmux
- [docs/security.md](docs/security.md): the tradeoffs, and what to revoke if the box is stolen

## Limitations

- `eso-phone` and `eso-rc-title` read Claude Code's transcript files, an internal format that
  can change between versions. If they stop working after an update, the rest still works.
- tmux sessions don't survive a reboot. The conversations do: `box`, then `claude --continue`
  or `/resume`.
- The Remote Control server serves one project folder. Sessions you start with `box` can `cd`
  anywhere.

## License

MIT
